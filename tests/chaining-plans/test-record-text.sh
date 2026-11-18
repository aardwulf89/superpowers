#!/usr/bin/env bash
# Pins chaining-plans' durable state (spec E § 6, E1–E3) in its text: the
# record is committed at docs/superpowers/efforts/<id>.json, it stores no
# branch, the phase branch is named by the phase id, the build's results
# travel in <phase id>.build.json, and phase state is read from evidence.
# Also pins the skill's namespace and its answer to pcvelz's handoff.
#
# Usage: tests/chaining-plans/test-record-text.sh
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

C=skills/chaining-plans
SK=$C/SKILL.md
RM=$C/references/record.md

for f in $SK $RM $C/references/create.md; do
  lacks "$f" '.superpowers/chain'
  lacks "$f" 'chain-dir'
  lacks "$f" 'effort.json'
  lacks "$f" 'superpowers:'
done

has $SK 'docs/superpowers/efforts/<id>.json'
has $SK 'worktree-<phase id>'
has $SK '<phase id>.build.json'
has $SK 'Subagent-Driven (this session)'
has $SK 'never picks a Parallel Session'
has $SK 'superpowers-extended-cc:writing-plans'

lacks $RM '"branch":'
lacks $RM '"worktree-K2"'
lacks $RM 'fill in as each stage ends'
has $RM 'from `<phase id>.build.json` at the close'
lacks $RM '### chain-dir'
lacks $RM '--chain-dir'
has $RM '--efforts-dir'
has $RM 'docs/superpowers/efforts/<id>.json'
for state in dropped cut-off close-missed "done" finished-unclosed closed-unmerged anomaly not-started; do
  has $RM "| \`$state\` |"
done
has $RM 'nine keys'
lacks $RM 'ten keys'
has $RM 'docs(<id>): record'
lacks $RM 'whose `branch` is null'

has $C/references/create.md 'docs/superpowers/efforts/<id>.json'
has $C/references/create.md 'superpowers-extended-cc:chaining-plans'

if ((failures)); then
  echo "FAIL: $failures of $checks record-text checks" >&2
  exit 1
fi
echo "PASS: all $checks record-text checks"
