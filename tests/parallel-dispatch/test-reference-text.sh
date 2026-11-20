#!/usr/bin/env bash
# Pins the text of the parallel-dispatch reference file (spec F, task F1.1):
# the strings its ten rules need, and the strings it must not carry.
#
# Usage: tests/parallel-dispatch/test-reference-text.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

failures=0
checks=0

# has FILE STRING: FILE (relative to the repo root) contains STRING.
has() {
  checks=$((checks + 1))
  if ! grep -qF -- "$2" "$REPO_ROOT/$1" 2>/dev/null; then
    echo "[FAIL] $1 lacks: $2" >&2
    failures=$((failures + 1))
  fi
}

# lacks FILE STRING: FILE does not contain STRING (a missing FILE fails).
lacks() {
  checks=$((checks + 1))
  if [[ ! -f "$REPO_ROOT/$1" ]] || grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 missing, or still has: $2" >&2
    failures=$((failures + 1))
  fi
}

F=skills/subagent-driven-development/references/parallel-dispatch.md
has  "$F" "Part of superpowers-extended-cc:subagent-driven-development."
has  "$F" "Ruling: dependencies"
has  "$F" ".superpowers/wt/"
has  "$F" "git check-ignore"
has  "$F" "While any nested worktree exists"
has  "$F" "git merge --ff-only"
has  "$F" "TMPDIR"
has  "$F" "commitStrategy"
has  "$F" "SUPERPOWERS_BLOCKEDBY_GUARD=0"
has  "$F" "Unfinished"
has  "$F" "review-package -C"
has  "$F" "rebase --abort"
has  "$F" "A task is ready when"
has  "$F" "You do not."
has  "$F" "Do not stop the run to ask"
has  "$F" "run in parallel without asking"
has  "$F" "Disjoint \`files\` lists are not enough"
has  "$F" "cost if wrong"
has  "$F" "worktree .superpowers/wt/<task id>)"
has  "$F" "approved (commits"
has  "$F" "git worktree remove <nested>"
has  "$F" "git branch -d <task id>"
has  "$F" "Never use \`--force\`"
has  "$F" "/sdd-<plan id>-<task id>"
has  "$F" "outside every worktree"
has  "$F" "The project's gates are"
lacks "$F" "cherry-pick <"
lacks "$F" " && git "
lacks "$F" "writer cap"
lacks "$F" "scripts/parallel"

# The ten rules keep the spec's order (Design items 1-10).
checks=$((checks + 1))
expected_heads='## 1. Dependencies come from the pre-flight scan, every run
## 2. One writer per tree
## 3. Reviewers read the task'"'"'s own worktree
## 4. The controller integrates; the ledger keeps its forms
## 5. Gates on the merged head
## 6. Resume
## 7. When parallel dispatch does not run
## 8. A unique temporary folder per writer
## 9. Ask first, beyond the plan
## 10. Known hazards'
actual_heads="$(grep -E '^## [0-9]+\. ' "$REPO_ROOT/$F" 2>/dev/null || true)"
if [[ "$actual_heads" != "$expected_heads" ]]; then
  echo "[FAIL] $F rule headings are not rules 1-10 in the spec's order" >&2
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "FAIL: $failures of $checks parallel-dispatch text checks" >&2
  exit 1
fi
echo "PASS: all $checks parallel-dispatch text checks"
