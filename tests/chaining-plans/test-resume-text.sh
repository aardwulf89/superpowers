#!/usr/bin/env bash
# Pins Resume on the pcvelz base (spec E § 4 and § 6): step-task titles of
# the form `<name> (<id>)`, no `branch` in the record, the anomaly row, the
# build's results committed on the phase branch, and the Plan stage's
# answer to pcvelz's handoff.
#
# Usage: tests/chaining-plans/test-resume-text.sh
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

R=skills/chaining-plans/references/resume.md

# Step tasks, name first.
has $R '"Missed close (A2)"'
has $R '"Missed git ops (A2)"'
has $R '"Design (A3)"'
has $R '"Build (K3)" → "Build (K3a)"'
lacks $R '"A2: Missed close"'
lacks $R '"A3: Design"'
lacks $R '"K3: Build"'

# The record stores no branch, and lives in git.
lacks $R 'Record `branch`'
lacks $R 'set` `branch`'
lacks $R 'whose `branch` is still null'
lacks $R "phase's \`branch\`"
lacks $R 'chain-dir'
lacks $R 'effort.json'
lacks $R 'superpowers:'
has $R 'docs/superpowers/efforts/<id>.json'
has $R '| `anomaly` |'

# The build's results travel with the build.
has $R '<phase id>.build.json'
has $R 'docs(<phase id>): build results'
lacks $R 'copy its\n  "Rulings I made" into `closing.rulings`'

# The Plan stage answers pcvelz's handoff, and the tasks file is committed with the plan.
has $R 'Subagent-Driven (this session)'
has $R '<phase id>.md.tasks.json'
has $R 'superpowers-extended-cc:subagent-driven-development'

# Missed git ops and PR cleanup follow finishing's lock rule.
has $R 'lock rule'

if ((failures)); then
  echo "FAIL: $failures of $checks resume-text checks" >&2
  exit 1
fi
echo "PASS: all $checks resume-text checks"
