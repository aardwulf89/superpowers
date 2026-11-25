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

# Pins match across line wraps: runs of spaces and newlines become one space.
flat() { tr -s ' \n' ' ' <"$REPO_ROOT/$1"; }

has() {
  checks=$((checks + 1))
  if ! flat "$1" | grep -qF -- "$2"; then
    echo "[FAIL] $1 lacks: $2" >&2
    failures=$((failures + 1))
  fi
}

lacks() {
  checks=$((checks + 1))
  if flat "$1" | grep -qF -- "$2"; then
    echo "[FAIL] $1 still has: $2" >&2
    failures=$((failures + 1))
  fi
}

FILES=(
  skills/writing-plans/SKILL.md
  skills/brainstorming/SKILL.md
  skills/chaining-plans/references/create.md
  skills/chaining-plans/references/resume.md
  skills/chaining-plans/references/close.md
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

C=skills/chaining-plans/references
lacks $C/create.md 'Work from the spec and from the reasons for the split'
has $C/create.md 'Draft phases only by the rule below.'
has $C/resume.md 'The design never divides the phase into plans.'
lacks $C/resume.md 'A further split from the Scope Check'
has $C/resume.md 'is a partner item: plan the phase whole'
has $C/close.md 'a split by the rule above'
has $C/close.md 'Its interim default is no split.'
lacks $C/record.md 'If a later part builds on the code of an earlier part'
has $C/record.md 'never for work order'
has $C/record.md "code or waits on it"
has skills/writing-plans/SKILL.md 'If the rule splits the work, say so and plan only the first part.'
has skills/brainstorming/SKILL.md 'If the rule splits it, say so and agree on an order.'
has $C/close.md '**A split made for size, or so that one part merges first,** is a partner item.'
has $C/resume.md '**A split made for size, or so that one part merges first,** is a partner item'

# Close: the block comes before the intent test, not between its question and answers.
checks=$((checks + 1))
b=$(grep -n '^<!-- split-rule -->$' "$REPO_ROOT/$C/close.md" | cut -d: -f1)
g=$(grep -n '^Go through every phase' "$REPO_ROOT/$C/close.md" | cut -d: -f1)
if ! [[ -n "$b" && -n "$g" && "$b" -lt "$g" ]]; then
  echo "[FAIL] $C/close.md: the block does not precede \"Go through every phase\"" >&2
  failures=$((failures + 1))
fi

# The fork bumps its version with every push that changes plugin content.
checks=$((checks + 1))
if ! grep -qF '"version": "7.1.2-dev+aardwulf.9"' "$REPO_ROOT/.claude-plugin/plugin.json"; then
  echo "[FAIL] .claude-plugin/plugin.json is not at 7.1.2-dev+aardwulf.9" >&2
  failures=$((failures + 1))
fi
has $C/resume.md "under the plan's Global Constraints"
has $C/resume.md "line of the plan's Global Constraints"

if ((failures)); then
  echo "FAIL: $failures of $checks split-rule checks" >&2
  exit 1
fi
echo "PASS: all $checks split-rule checks"
