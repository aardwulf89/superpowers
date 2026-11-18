#!/usr/bin/env bash
# Pins the reference-style id forms (spec K, phase K3, task K3.4) each skill
# must write, and the old forms (Task N, dated paths) it must no longer
# contain.
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
B=skills/brainstorming/SKILL.md
lacks $B 'YYYY-MM-DD'
has $B 'docs/superpowers/specs/<letter>.md'
has $B '# <letter>: <Title>'
has $B 'bash scripts/next-spec-id'
has $B 'when you first save the doc'
has $B 'else `K: …`'

# --- writing-plans ---
W=skills/writing-plans/SKILL.md
lacks $W 'YYYY-MM-DD'
lacks $W '2026-01-15-feature.md'
lacks $W '### Task N:'
lacks $W 'Task N: [Component Name]'
lacks $W 'plans/<filename>.md'
lacks $W '"subject": "Task 0'
lacks $W 'git commit -m "feat: add specific feature"'
has $W 'docs/superpowers/plans/<plan id>.md'
has $W '# <plan id>: [Feature Name] Implementation Plan'
has $W '### Task <plan id>.<n>: [Component Name]'
has $W 'git commit -m "feat(<plan id>.<n>): add specific feature"'
has $W '../brainstorming/scripts/next-spec-id'
has $W '--phase'
has $W '#### Task K3.4a'
has $W '**6. Ids:**'
has $W 'subject: "<task id>: [Component Name]"'
has $W 'docs/superpowers/plans/K3.md.tasks.json'
has $W '"subject": "K3.1: '

# --- requesting-code-review ---
R=skills/requesting-code-review/SKILL.md
lacks $R 'grep "Task 1"'
lacks $R 'deployment-plan.md'
has $R 'Task B1.2'
has $R 'docs/superpowers/plans/B1.md'
has $R '(B1.1)'

# --- the gate skills and shared text ---
lacks skills/specifying-gates/SKILL.md 'for Task N.'
has skills/specifying-gates/SKILL.md 'for Task <id>.'
lacks skills/checking-gates/SKILL.md "Task N's"
has skills/checking-gates/SKILL.md "Task <id>'s"
lacks README.md 'subject: "Task 1:'
lacks docs/user-gate-flow.md '- Task 7:'

# --- the at-end notice ---
lacks hooks/session-start 'Task <N>: complete'
has hooks/session-start 'Task <id>: complete (working tree, at-end strategy, review clean)'
has hooks/session-start 'feat(<plan id>):'

if ((failures)); then
  echo "FAIL: $failures of $checks id-form checks" >&2
  exit 1
fi
echo "PASS: all $checks id-form checks"
