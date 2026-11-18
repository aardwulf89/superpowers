#!/usr/bin/env bash
# Pins spec E § 4's task rules in the skill text: one signal (a task is a
# work task iff it carries a json:metadata block), each skill touches only
# its own tasks, no duplicate tasks, the split rule, and step-task titles of
# the form `<name> (<id>)`.
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

W=skills/writing-plans/SKILL.md
S=skills/subagent-driven-development
E=skills/executing-plans/SKILL.md

# --- one signal: writing-plans enhances only work tasks ---
has $W 'enhance only the tasks that carry a `json:metadata` block'

# --- no duplicates: SDD takes executing-plans' Step 0 order ---
lacks $S/SKILL.md 'Then `TaskCreate` a task per plan task with the full task text.'
has $S/SKILL.md 'Step 0'
has $S/SKILL.md '.tasks.json'
has $S/SKILL.md 'TaskList'
has $S/SKILL.md 'compare only work tasks'
has $E 'compare only work tasks'

# --- the split rule ---
for f in $S/references/handling-reports.md $E; do
  has "$f" 'split into <id>a'
  has "$f" 'is never dispatched'
  has "$f" 'completes when its last part does'
  has "$f" 'full work task'
  lacks "$f" 'Do not edit the plan. Each part'
done
has $S/references/handling-reports.md 'K3.4a1'
has $E 'K3.4a1, K3.4a2'
has $S/references/resuming.md 'every part the ruling names'
has $E 'every part the ruling names'

# --- the executors make no step tasks (spec E § 4) ---
for f in $S/SKILL.md $E; do
  lacks "$f" 'Final whole-branch review (<plan id>)'
  lacks "$f" 'Deferred-findings round (<plan id>)'
  lacks "$f" '"<plan id>: Final whole-branch review"'
  lacks "$f" '"<plan id>: Finish"'
  lacks "$f" 'Do not make a task whose title is in the task list already'
done

# --- chaining-plans: step tasks are `<name> (<id>)`, never `<id>: <name>` ---
C=skills/chaining-plans
has $C/SKILL.md '`<name> (<id>)`'
has $C/SKILL.md 'never a `json:metadata` block'
for step in 'Draft the phases' 'Find the open intent questions' 'Run one sitting' 'Write it down' 'Hand over'; do
  has $C/references/create.md "\"$step (K)\""
  lacks $C/references/create.md "\"K: $step\""
done
# Create touches only its own tasks: it never deletes brainstorming's.
lacks $C/references/create.md 'status `deleted`'

if ((failures)); then
  echo "FAIL: $failures of $checks task-list checks" >&2
  exit 1
fi
echo "PASS: all $checks task-list checks"
