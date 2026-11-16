#!/usr/bin/env bash
# Pins the wording that ends an effort only once every partner item has a
# disposition, and that brings carried items to the next Create: Resume's
# end round and last message, and Create's marked record and `carried` read.
#
# Usage: tests/chaining-plans/test-carry-text.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

failures=0
checks=0

# has FILE STRING: FILE (relative to the repo root) contains STRING.
has() {
  checks=$((checks + 1))
  if ! grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 lacks: $2" >&2
    failures=$((failures + 1))
  fi
}

# lacks FILE STRING: FILE does not contain STRING.
lacks() {
  checks=$((checks + 1))
  if grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 still has: $2" >&2
    failures=$((failures + 1))
  fi
}

R=skills/chaining-plans/references
has $R/resume.md '## 5. The end of the effort'
has $R/resume.md '`items`'
has $R/resume.md '`unmarked`'
has $R/resume.md 'Effort <id> is finished, but NOT closed out'
has $R/resume.md 'Effort <id> is closed out: every phase is done or dropped, and no item is open.'
has $R/resume.md 'interim default'
lacks $R/resume.md '## 5. Run the stages'

has $R/create.md '"marked": true'
has $R/create.md 'record.py carried'

if ((failures > 0)); then
  echo "$failures of $checks checks failed" >&2
  exit 1
fi
echo "PASS: all $checks carry wording checks"
