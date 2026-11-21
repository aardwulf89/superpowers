#!/usr/bin/env bash
# Pins the text in writing-plans/SKILL.md that defines a hard dependency
# (spec H, task H1.1): the definition under "### Setting Dependencies", the
# blockedBy wording that replaces the old "After all tasks created" line, and
# a K3.3 task with no blockedBy in the .tasks.json example.
#
# Usage: tests/parallel-dispatch/test-plan-dependencies.sh
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

W=skills/writing-plans/SKILL.md

has   "$W" "Task B waits for task A only when B cannot be completed in a tree without A's commits"
has   "$W" "Plan order, a shared file, and text that only repeats what the plan already fixes are never reasons."
has   "$W" "\"subject\": \"K3.3: ...\""
lacks "$W" "After all tasks created, set blockedBy relationships:"

if ((failures)); then
  echo "FAIL: $failures of $checks plan-dependency text checks" >&2
  exit 1
fi
echo "PASS: all $checks plan-dependency text checks"
