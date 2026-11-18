#!/usr/bin/env bash
# Pins the task-list rules: the `<id>: <name>` schema, blockers, status, and
# who makes the Finish task.
#
# Usage: tests/task-list/test-task-list-text.sh
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

# --- executors ---
for f in skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md; do
  has "$f" '"K3.4: Add retry wrapper"'
  lacks "$f" '"Task K3.4: Add retry wrapper"'
  has "$f" '("Tasks 1-14")'
  has "$f" '"<plan id>: Final whole-branch review"'
  has "$f" '"<plan id>: Deferred-findings round"'
  lacks "$f" 'Deferred-findings round and finish'
  has "$f" '"<plan id>: Finish"'
  has "$f" 'If a task with that title exists already'
  has "$f" 'blockedBy'
  has "$f" 'no completion line'
done

# --- chaining-plans: resume ---
R=skills/chaining-plans/references/resume.md
has "$R" '("A3: Design")'
lacks "$R" '("A3 Design")'
has "$R" '("A3 Design → Plan → Build → Finish → Close")'
has "$R" '"Building A3"'
has "$R" '`activeForm`'
has "$R" '`blockedBy`'
has "$R" '"A2: Missed close"'
has "$R" '"A2: Missed git ops"'
has "$R" 'by every task of step 3'
has "$R" 'stays in_progress'
has "$R" '("K3: Build" → "K3a: Build")'
has "$R" 'Retitle each stage task that is not completed'

if ((failures)); then
  echo "FAIL: $failures of $checks task-list checks" >&2
  exit 1
fi
echo "PASS: all $checks task-list checks"
