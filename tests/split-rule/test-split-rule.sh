#!/usr/bin/env bash
# Pins spec J: one identical "Splitting into plans" block, once in each
# file that splits work into plans, and the split wording it replaced.
#
# Usage: tests/split-rule/test-split-rule.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

failures=0
checks=0

has() {
  checks=$((checks + 1))
  if ! grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 lacks: $2" >&2
    failures=$((failures + 1))
  fi
}

lacks() {
  checks=$((checks + 1))
  if grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 still has: $2" >&2
    failures=$((failures + 1))
  fi
}

FILES=(
  skills/writing-plans/SKILL.md
  skills/brainstorming/SKILL.md
)

block() {
  sed -n '/^<!-- split-rule -->$/,/^<!-- \/split-rule -->$/p' "$REPO_ROOT/$1"
}

first=""
for f in "${FILES[@]}"; do
  checks=$((checks + 1))
  n=$(grep -c '^<!-- split-rule -->$' "$REPO_ROOT/$f" || true)
  if [[ "$n" != 1 ]]; then
    echo "[FAIL] $f holds $n copies of the block (want 1)" >&2
    failures=$((failures + 1))
    continue
  fi
  if [[ -z "$first" ]]; then
    first="$f"
    checks=$((checks + 1))
    if ! block "$f" | grep -qF '**Splitting into plans.**'; then
      echo "[FAIL] $f: the block lacks its heading" >&2
      failures=$((failures + 1))
    fi
  elif ! diff <(block "$first") <(block "$f") >/dev/null; then
    echo "[FAIL] $f: the block differs from $first" >&2
    failures=$((failures + 1))
  fi
done

lacks skills/writing-plans/SKILL.md 'one per subsystem'
lacks skills/brainstorming/SKILL.md 'If this is really several independent projects'
has skills/brainstorming/SKILL.md 'It proposes no phases or plans.'

if ((failures)); then
  echo "FAIL: $failures of $checks split-rule checks" >&2
  exit 1
fi
echo "PASS: all $checks split-rule checks"
