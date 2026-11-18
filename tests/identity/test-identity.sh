#!/usr/bin/env bash
# Pins the fork's identity on the pcvelz base: plugin name, marketplace name,
# install-path references, and the private-fork block in AGENTS.md.
#
# Usage: tests/identity/test-identity.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

failures=0
checks=0
pass() { checks=$((checks + 1)); }
fail() {
  checks=$((checks + 1))
  echo "[FAIL] $1" >&2
  failures=$((failures + 1))
}
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass; else fail "$1: expected '$2', got '$3'"; fi
}
has() { if grep -qF -- "$2" "$1"; then pass; else fail "$1 lacks: $2"; fi; }

check "marketplace name" superpowers-aardwulf "$(jq -r .name .claude-plugin/marketplace.json)"
check "marketplace plugin name" superpowers-extended-cc "$(jq -r '.plugins[0].name' .claude-plugin/marketplace.json)"
check "plugin name" superpowers-extended-cc "$(jq -r .name .claude-plugin/plugin.json)"

# pcvelz's marketplace install path, which does not exist on this fork's
# installs. Built from parts so this file does not match itself.
old="superpowers-extended-cc-""marketplace"
stray=$(git grep -l -F -- "$old" -- ':!docs/superpowers' || true)
check "no pcvelz marketplace path outside docs/superpowers" "" "$stray"

has AGENTS.md '**Private fork.**'
has AGENTS.md '<pcvelz version>+aardwulf.<N>'
has AGENTS.md '## If You Are an AI Agent'

if ((failures)); then
  echo "$failures of $checks identity checks failed" >&2
  exit 1
fi
echo "All $checks identity checks passed"
