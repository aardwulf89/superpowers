#!/usr/bin/env bash
# Pins chaining-plans' effort-level `learned` (spec K) in its text: record.md
# documents get-effort and set-effort-key, Create seeds the list and copies
# the standing rules, Resume's Design reads it before the done phases'
# closing.learned, and each close revises it.
#
# Usage: tests/chaining-plans/test-effort-learned-text.sh
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

C=skills/chaining-plans
has $C/references/record.md '### get-effort'
has $C/references/record.md '### set-effort-key'
has $C/references/record.md 'A record without `learned` reads as null'
has $C/references/create.md 'If the session holds no brainstorm, the seed is `[]`'
has $C/references/create.md 'standing rules'
has $C/references/resume.md '`record.py get-effort REC learned`'
has $C/references/close.md 'record.py set-effort-key REC learned edit'
has $C/SKILL.md '`record.py set-effort-key`'

# Design reads the effort's learned before the done phases'.
checks=$((checks + 1))
e=$(grep -nF 'record.py get-effort REC learned' "$REPO_ROOT/$C/references/resume.md" | head -1 | cut -d: -f1 || true)
p=$(grep -nF 'closing.learned` of every done phase' "$REPO_ROOT/$C/references/resume.md" | head -1 | cut -d: -f1 || true)
if [[ -z "$e" || -z "$p" ]]; then
  echo "[FAIL] resume.md Design inputs lack the get-effort line or the closing.learned line" >&2
  failures=$((failures + 1))
elif ((e >= p)); then
  echo "[FAIL] resume.md lists the effort learned (line $e) after the done phases' closing.learned (line $p)" >&2
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "FAIL: $failures of $checks effort-learned text checks" >&2
  exit 1
fi
echo "PASS: all $checks effort-learned text checks"
