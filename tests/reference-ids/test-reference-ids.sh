#!/usr/bin/env bash
# Pins the reference-style id forms (spec K, phase K3, task K3.4) each skill
# must write, and the old forms (Task N, dated paths, p<n>-<slug>) it must
# no longer contain.
#
# Usage: tests/reference-ids/test-reference-ids.sh
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

# --- brainstorming ---
lacks skills/brainstorming/SKILL.md 'YYYY-MM-DD-<topic>-design.md'
has skills/brainstorming/SKILL.md 'docs/superpowers/specs/<letter>.md'
has skills/brainstorming/SKILL.md '# <letter>: <Title>'
has skills/brainstorming/SKILL.md 'scripts/next-spec-id'
lacks skills/brainstorming/SKILL.md 'just before the commit'
has skills/brainstorming/SKILL.md 'when you first save the doc'

# --- writing-plans ---
lacks skills/writing-plans/SKILL.md 'YYYY-MM-DD-<feature-name>.md'
lacks skills/writing-plans/SKILL.md '### Task N:'
lacks skills/writing-plans/SKILL.md 'in Task 3 but'
lacks skills/writing-plans/SKILL.md 'git commit -m "feat: add specific feature"'
has skills/writing-plans/SKILL.md 'docs/superpowers/plans/<plan id>.md'
has skills/writing-plans/SKILL.md '# <plan id>: [Feature Name] Implementation Plan'
has skills/writing-plans/SKILL.md '### Task <plan id>.<n>: [Component Name]'
has skills/writing-plans/SKILL.md 'git commit -m "feat(<plan id>.<n>): add specific feature"'
has skills/writing-plans/SKILL.md '../brainstorming/scripts/next-spec-id'
has skills/writing-plans/SKILL.md '--phase'
has skills/writing-plans/SKILL.md '#### Task K3.4a'
has skills/writing-plans/SKILL.md '**6. Ids:**'

# --- requesting-code-review ---
lacks skills/requesting-code-review/SKILL.md 'grep "Task 1"'
lacks skills/requesting-code-review/SKILL.md 'deployment-plan.md'
has skills/requesting-code-review/SKILL.md 'Task B1.2'
has skills/requesting-code-review/SKILL.md 'docs/superpowers/plans/B1.md'
has skills/requesting-code-review/SKILL.md '(B1.1)'

# --- subagent-driven-development ---
S=skills/subagent-driven-development
lacks $S/SKILL.md '"Task 3: Add retry'
lacks $S/SKILL.md 'Task <N>'
lacks $S/SKILL.md 'task-N-'
has $S/SKILL.md 'task-<id>-report.md'
has $S/SKILL.md 'as its plan heading writes it'
has $S/SKILL.md '"Task K3.4: Add retry wrapper"'
has $S/SKILL.md '"<plan id>: Final whole-branch review"'
has $S/SKILL.md '"<plan id>: Deferred-findings round and finish"'
has $S/SKILL.md 'Task <id>: complete'
has $S/SKILL.md '<plan id>: Ruling:'
has $S/SKILL.md 'scripts/task-brief PLAN_FILE <id>'
has $S/SKILL.md "named after the plan's id"
lacks $S/implementer-prompt.md 'Task N'
has $S/implementer-prompt.md 'Task [TASK_ID]'
has $S/implementer-prompt.md 'feat([TASK_ID]):'
lacks $S/task-reviewer-prompt.md 'Task N'
has $S/task-reviewer-prompt.md 'Task [TASK_ID]'
lacks $S/re-review-prompt.md 'Task N'
has $S/re-review-prompt.md 'Task [TASK_ID]'
lacks $S/references/resuming.md 'Task <N>'
has $S/references/resuming.md 'every part the ruling names'
has $S/references/handling-reports.md 'split into <id>a'
has $S/SKILL.md 'never the parent on its own'
has $S/references/resuming.md 'nested part headings'
lacks $S/references/fix-loop.md 'Task <N>'
has $S/references/fix-loop.md 'Task <id>: parked'
has $S/references/final-review.md 'fix(<plan id>):'
has $S/references/deferred-findings.md 'fix(<plan id>):'

# --- executing-plans ---
E=skills/executing-plans
lacks $E/SKILL.md '"Task 3: Add retry'
lacks $E/SKILL.md 'Task <N>'
lacks $E/SKILL.md 'Task N says'
lacks $E/SKILL.md '`Final: '
has $E/SKILL.md 'as its plan heading writes it'
has $E/SKILL.md '"Task K3.4: Add retry wrapper"'
has $E/SKILL.md '"<plan id>: Final whole-branch review"'
has $E/SKILL.md 'scripts/task-start PLAN_FILE <id>'
has $E/SKILL.md 'scripts/task-done PLAN_FILE <id> BASE'
has $E/SKILL.md '<plan id>: Final: Ruling:'
has $E/SKILL.md '<plan id>: Ruling:'
has $E/SKILL.md 'split into <id>a'
has $E/SKILL.md 'every part the ruling names'
has $E/SKILL.md "named after the plan's id"
has $E/SKILL.md 'never the parent on its own'
has $E/SKILL.md 'nested part headings'
lacks $E/references/deferred-findings.md '`Final: '
has $E/references/deferred-findings.md '<plan id>: Final: fixed'
has $E/references/deferred-findings.md 'fix(<plan id>):'

# --- chaining-plans ---
C=skills/chaining-plans
for f in $C/SKILL.md $C/references/create.md $C/references/resume.md $C/references/close.md $C/references/record.md; do
  lacks "$f" 'p<n>-<slug>'
  lacks "$f" 'p1-storage'
  lacks "$f" 'p1-executor'
  lacks "$f" 'p2-runtime'
  lacks "$f" 'p3-types'
  lacks "$f" '<date>-<umbrella topic>'
  lacks "$f" '<date>-<topic>-design.md'
  lacks "$f" '"p2-x"'
done
has $C/SKILL.md 'docs/superpowers/specs/<phase id>.md'
has $C/SKILL.md "umbrella's spec letter"
has $C/references/create.md 'next-spec-id'
has $C/references/create.md '### K1: Storage'
has $C/references/create.md 'docs(K):'
has $C/references/resume.md 'docs/superpowers/specs/<phase id>.md'
has $C/references/resume.md 'K2a'
has $C/references/record.md '"id": "K2"'
has $C/references/record.md '"depends_on": ["K1"]'
has $C/references/record.md '"affects": ["K3"]'
has $C/references/record.md 'K2a1'
has $C/references/record.md '**Merged from:**'
has $C/references/close.md '"affects": ["K3"]'
has $C/references/close.md '**Merged from:**'

# --- deferred-findings round ---
has $S/references/handling-reports.md 'K3.4a1'
has $E/SKILL.md 'K3.4a1, K3.4a2'
has skills/brainstorming/SKILL.md 'else `K: …`'
has skills/chaining-plans/SKILL.md 'else `K3: …`'
lacks $S/references/preflight.md 'Task 1'
lacks $E/SKILL.md 'Task 1'
has $S/references/preflight.md '<plan id>: Ruling:'
has $S/SKILL.md 'for a plan with an id is named'
has $E/SKILL.md 'for a plan with an id is named'

if ((failures)); then
  echo "FAIL: $failures of $checks id-form checks" >&2
  exit 1
fi
echo "PASS: all $checks id-form checks"
