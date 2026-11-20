#!/usr/bin/env bash
# Pins the text that points the subagent-driven-development skill at the
# parallel-dispatch reference (spec F, task F1.2): the trigger in SKILL.md,
# the phrase changes in §Bounded Parallel Dispatch, the Setup node label,
# the pre-flight dependency ruling and the resume pointer.
#
# Usage: tests/parallel-dispatch/test-skill-text.sh
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

S=skills/subagent-driven-development/SKILL.md
P=skills/subagent-driven-development/references/preflight.md
R=skills/subagent-driven-development/references/resuming.md

has   "$S" "you dispatch: each writer gets its own worktree. Never two writers in one"
lacks "$S" "Never dispatch multiple implementation subagents in parallel (conflicts)"
has   "$S" "**Run implementers concurrently ONLY when** neither depends on the other in the pre-flight's dependency ruling. Give each its own worktree (references/parallel-dispatch.md)."
has   "$S" "neither depends on the other in the pre-flight's dependency ruling"
lacks "$S" "in the other's \`blockedBy\` chain"
lacks "$S" "remains the default; parallelism is the optimization"
has   "$S" "pre-flight review and dependency ruling"
lacks "$S" "read plan, pre-flight review\" ["
lacks "$S" "read plan, pre-flight review\" ->"
has   "$P" "Ruling: dependencies"
has   "$R" "parallel-dispatch.md"
has   "$P" "cost if wrong"
has   "$R" "rule 6 of [parallel-dispatch.md]"
has   "$R" "approved (commits"
has   "$S" "holds in every mode"
lacks "$S" "is the default for the sequential loop"

lacks "$S" "The \`files\` metadata IS the test"
lacks "$S" "lists share no path AND"
has   "$S" "(dispatch, fix round, approved, complete, minor, parked, BLOCKED)"
has   "$S" "agent passes the disjointness test:"

has   "$P" "A shared file is never a reason"
has   "$P" "One worktree is never a reason"
has   "$P" "both take from an allocator"
has   "$P" "[parallel-dispatch.md](parallel-dispatch.md) before you dispatch."
has   "$S" "A task reviewer reads only its own task's tree."
has   "$S" "are parked at the cap."
lacks "$P" "From the table's rows for shared files and interfaces, rule"

has   "$P" "from the table's rows and the plan's text"

if ((failures)); then
  echo "FAIL: $failures of $checks parallel-dispatch skill text checks" >&2
  exit 1
fi
echo "PASS: all $checks parallel-dispatch skill text checks"
