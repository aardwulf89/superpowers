#!/usr/bin/env bash
# Pins the native-worktree rules (spec B, spec E § 7): finishing detects the
# worktree with plain calls, leaves a confined worktree with ExitWorktree
# keep before the merge, removes the .claude/worktrees/ worktree it entered
# and left, unlocks a stale lock only after checking its process is dead,
# and discards through ExitWorktree remove. using-git-worktrees Step 4 and
# executing-plans' re-entry agree with it.
#
# Usage: tests/native-worktrees/test-native-worktree-text.sh
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

# in_order FILE A B: A appears on an earlier line of FILE than B.
in_order() {
  checks=$((checks + 1))
  local a b
  a=$({ grep -nF -- "$2" "$REPO_ROOT/$1" || true; } | head -1 | cut -d: -f1)
  b=$({ grep -nF -- "$3" "$REPO_ROOT/$1" || true; } | head -1 | cut -d: -f1)
  if [[ -z $a || -z $b || $a -ge $b ]]; then
    echo "[FAIL] $1: '$2' does not come before '$3'" >&2
    failures=$((failures + 1))
  fi
}

F=skills/finishing-a-development-branch/SKILL.md
# Step 2: plain calls, no compound capture.
has $F 'git rev-parse --path-format=absolute --git-dir'
lacks $F 'GIT_DIR=$(cd'
lacks $F 'GIT_COMMON=$(cd'
lacks $F '"$WORKTREE_PATH"'
# Option 1: leave with keep before the merge.
has $F '`ExitWorktree`, action `keep`'
in_order $F '`ExitWorktree`, action `keep`' 'git merge <feature-branch>'
# Cleanup: the .claude/worktrees/ worktree this session entered and left.
has $F 'or the `.claude/worktrees/` one this session entered and left'
# The stale-lock rule.
has $F 'git worktree list --porcelain'
has $F 'ps -p <pid>'
has $F 'git worktree unlock <WORKTREE_PATH>'
in_order $F 'ps -p <pid>' 'git worktree unlock <WORKTREE_PATH>'
has $F 'another session still has the worktree open'
lacks $F 'remove -f -f'
lacks $F 'git worktree remove --force'
# Discard.
has $F 'discard_changes: true'
has $F 'not the owner'

W=skills/using-git-worktrees/SKILL.md
has $W 'merged locally'
has $W 'finishing-a-development-branch'
lacks $W 'Prefer this over `git worktree remove`.'

E=skills/executing-plans/SKILL.md
has $E '`EnterWorktree` with its `path`'
lacks $E 'cd into it'

if ((failures)); then
  echo "FAIL: $failures of $checks native-worktree checks" >&2
  exit 1
fi
echo "PASS: all $checks native-worktree checks"
