#!/usr/bin/env bash
# Pins Close on the pcvelz base (spec E § 6, E1–E3): it reads the build's
# results from <phase id>.build.json on the ref, finds the phase's commits by
# one ancestry range, never by a merge search or gh, finds the record in git,
# and a discard resets no branch.
#
# Usage: tests/chaining-plans/test-close-text.sh
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

C=skills/chaining-plans/references/close.md

has $C 'show <ref>:docs/superpowers/plans/<phase id>.build.json'
has $C '--ancestry-path <anchor>..<end>'
has $C 'git log --format=%H -1 <ref> -- docs/superpowers/plans/<phase id>.build.json'
lacks $C 'gh pr view'
lacks $C "git log --merges --first-parent --format='%H %s'"
lacks $C 'git rev-list --merges --first-parent'
lacks $C "set\` the phase's \`branch\` to null"
lacks $C "phase's \`branch\`"
lacks $C 'chain-dir'
lacks $C 'effort.json'
lacks $C 'superpowers:'
has $C 'docs/superpowers/efforts/<effort id>.json'
has $C 'docs(<phase id>): record'
has $C 'superpowers-extended-cc:chaining-plans'

if ((failures)); then
  echo "FAIL: $failures of $checks close-text checks" >&2
  exit 1
fi
echo "PASS: all $checks close-text checks"
