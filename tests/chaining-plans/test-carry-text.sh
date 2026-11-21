#!/usr/bin/env bash
# Pins the wording that ends an effort only once every partner item has a
# disposition, and that brings carried items to the next Create: Resume's
# end round and last message, Create's `carried` read, and Close's sort of
# partner items, its check before writing and its revise step.
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
has $R/resume.md 'Effort <id> is finished, but NOT closed out'
has $R/resume.md 'Effort <id> is closed out: every phase is done or dropped, and no item is open.'
has $R/resume.md 'interim default'
lacks $R/resume.md '## 5. Run the stages'

has $R/create.md 'record.py carried'

has $R/close.md 'Partner item: '
has $R/close.md 'interim default'
has $R/close.md 'commits to nothing new'
has $R/close.md '### 1a. Revise'
has $R/close.md 'the branch tip'
has $R/close.md 'Open for you:'
has $R/close.md '## 5. The end of the effort'
has skills/chaining-plans/SKILL.md 'Partner item'

# An end-round answer that calls for work settles its item first.
has $R/resume.md '**An answer that calls for work** is a settle'
# A discard sorts the executor's lines before it keeps the partner items.
has $R/close.md 'first sort every `unfinished` line by the sort at the'
# A dropped phase's question from a partner-item line loses its pointer, and
# a split or a merge moves a pointer to the phase that holds the question.
has $R/close.md 'pointer off the line, with the space before it'
has $R/record.md '**A pointer follows its question.**'
# `none` is closed out only when no item is carried.
has $R/record.md 'The effort is closed out, unless an item is'
# Answers given outside a round are folded in before the pick, not only in
# the Intent round.
has $R/resume.md '### Answers given outside a round'
lacks $R/resume.md '**Answers given outside any round,**'
# `carried` reads only this repo's efforts directory.
has $R/resume.md "The next effort's Create in this repo will show them to you."
# The check before writing names both refs it reads.
has $R/close.md '`<ref>` the record'"'"'s `base` once merged, else the phase branch'
# The report line counts no blocking item.
has $R/close.md 'Count only the lines'

# G1: a carried item changes by its text.
has $R/create.md 'unfinished edit'
lacks $R/create.md 'Change the line at `index`'

if ((failures > 0)); then
  echo "$failures of $checks checks failed" >&2
  exit 1
fi
echo "PASS: all $checks carry wording checks"
