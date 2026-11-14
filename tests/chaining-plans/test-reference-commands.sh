#!/usr/bin/env bash
# Pins that chaining-plans' references run the record through
# scripts/record.py, one plain command per call, and no longer through inline
# shell blocks and jq, which Claude Code's worktree isolation refuses.
#
# Usage: tests/chaining-plans/test-reference-commands.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/chaining-plans"
RECORD_MD="$SKILL/references/record.md"

failures=0
fail() { echo "[FAIL] $1" >&2; failures=$((failures + 1)); }

SUBCOMMANDS="chain-dir open-efforts phase-state pick get questions new-record set set-phases set-closing-key"

# The old inline forms are gone from every file but the script itself.
for pattern in 'jq' '<!-- cmd:' 'value_json' 'phases_json' 'record_json' 'same Bash call'; do
  hits=$(grep -rlF -- "$pattern" "$SKILL" | grep -v '/scripts/record\.py$' || true)
  if [[ -n "$hits" ]]; then fail "'$pattern' still in: ${hits//$REPO_ROOT\//}"; fi
done

# record.md documents every subcommand under its own heading.
for name in $SUBCOMMANDS; do
  grep -qx "### $name" "$RECORD_MD" || fail "record.md has no '### $name' heading"
done

# Every record.py <word> the docs name is a real subcommand.
while IFS= read -r word; do
  case " $SUBCOMMANDS " in
    *" $word "*) ;;
    *) fail "the docs name 'record.py $word', which is not a subcommand" ;;
  esac
done < <(grep -rhoE 'record\.py [a-z][a-z-]*' "$SKILL" --include='*.md' | awk '{print $2}' | sort -u)

# The record's shape and the set-phases rules stay where the id test looks.
bash "$REPO_ROOT/tests/reference-ids/test-reference-ids.sh" >/dev/null || fail "tests/reference-ids fails"

if ((failures > 0)); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "PASS: chaining-plans references run the record script"
