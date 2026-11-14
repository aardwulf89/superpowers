#!/usr/bin/env bash
# Pins the wording that lets chaining-plans and finishing run inside a
# worktree the harness confines the session to (Claude Code's EnterWorktree):
# leave it before work in the main checkout, record the branch name the tool
# gives, and clean the worktree up after the merge.
#
# Usage: tests/native-worktrees/test-native-worktree-text.sh
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

# --- chaining-plans ---
C=skills/chaining-plans
lacks $C/SKILL.md 'the branch name,'
lacks $C/SKILL.md 'Each phase gets its own branch, named by its phase'
has $C/SKILL.md 'worktree-<phase id>'
for s in 'EnterWorktree' 'ExitWorktree' '.claude/worktrees/' 'git merge-base --is-ancestor' 'worktree-<phase id>'; do
  has $C/references/resume.md "$s"
done
has $C/references/close.md 'ExitWorktree'

if ((failures > 0)); then
  echo "$failures of $checks checks failed" >&2
  exit 1
fi
echo "PASS: all $checks native-worktree wording checks"
