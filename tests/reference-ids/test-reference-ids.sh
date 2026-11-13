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

if ((failures)); then
  echo "FAIL: $failures of $checks id-form checks" >&2
  exit 1
fi
echo "PASS: all $checks id-form checks"
