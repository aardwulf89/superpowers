#!/usr/bin/env bash
# Pins spec E § 4a fix 3: the plan's .tasks.json is committed with the plan,
# updated in the working tree's own copy, and committed before the executor
# deletes its workspace, so it works inside an EnterWorktree worktree
# (where Edit and Write to the main checkout are refused, and
# `git worktree remove` refuses a dirty worktree).
#
# Usage: tests/tasks-json/test-tasks-json-text.sh
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

S=skills/subagent-driven-development
E=skills/executing-plans/SKILL.md

has skills/writing-plans/SKILL.md 'commit the plan and its tasks file together'
has skills/writing-plans/SKILL.md 'docs(<plan id>): plan'

for f in $S/SKILL.md $E; do
  has "$f" "the working tree's copy"
  lacks "$f" '.tasks.json` in the main checkout'
done
for f in $S/references/final-review.md $E; do
  has "$f" 'if it changed'
  has "$f" 'chore(<plan id>): task status'
done

has skills/dispatching-parallel-agents/SKILL.md "the working tree's copy"
has skills/specifying-gates/SKILL.md "the working tree's copy"

if ((failures)); then
  echo "FAIL: $failures of $checks tasks-file checks" >&2
  exit 1
fi
echo "PASS: all $checks tasks-file checks"
