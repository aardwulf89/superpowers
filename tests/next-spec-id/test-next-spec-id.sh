#!/usr/bin/env bash
# Tests skills/brainstorming/scripts/next-spec-id against fixture git repos.
#
# Usage: tests/next-spec-id/test-next-spec-id.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NEXT="$REPO_ROOT/skills/brainstorming/scripts/next-spec-id"

failures=0
pass() { echo "[PASS] $1"; }
fail() {
  echo "[FAIL] $1" >&2
  failures=$((failures + 1))
}
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1: expected '$2', got '$3'"; fi
}

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

S=docs/superpowers/specs
P=docs/superpowers/plans

# A fresh repo on main with no commits; prints its path.
new_repo() {
  local r
  r=$(mktemp -d "$ROOT/r.XXXXXX")
  mkdir -p "$r/$S" "$r/$P"
  git -C "$r" init -q -b main
  git -C "$r" config user.email t@example.invalid
  git -C "$r" config user.name t
  echo "$r"
}

# Write a doc whose first line is $3 at path $2 in repo $1.
doc() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n\nbody\n' "$3" >"$1/$2"
}

commit_all() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }

# Run next-spec-id inside repo $1 with the remaining args; prints stdout.
run() {
  local r=$1
  shift
  (cd "$r" && bash "$NEXT" "$@")
}

r=$(new_repo)
check "empty repo, no commits" A "$(run "$r")"

for pair in H:J N:P Z:AA AH:AJ ZZ:AAA; do
  used=${pair%%:*} want=${pair##*:}
  r=$(new_repo)
  doc "$r" "$S/$used.md" "# $used: x"
  check "after $used" "$want" "$(run "$r")"
done

r=$(new_repo)
doc "$r" "$S/A.md" "# A: x"
doc "$r" "$S/C.md" "# C: x"
check "gap kept" D "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/2026-01-01-x-design.md" "# X design"
doc "$r" "$S/README.md" "# README"
check "legacy and README ignored" A "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/2026-01-01-x-design.md" "# B: X design"
check "legacy stamped" C "$(run "$r")"

r=$(new_repo)
doc "$r" "$P/D1.md" "# D1: x"
check "plan only" E "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/2026-01-01-x-design.md" "# X design"
commit_all "$r" first
doc "$r" "$S/K.md" "# K: x"
commit_all "$r" second
git -C "$r" checkout -q -b old HEAD~1
check "base only" L "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/K.md" "# K: x"
check "working tree only" L "$(run "$r")"

r=$(new_repo)
mkdir -p "$r/.superpowers/chain/M"
check "record dir" N "$(run "$r")"

r=$(new_repo)
doc "$r" "notes/specs/F.md" "# F: x"
mkdir -p "$r/notes/plans"
check "custom dirs" G "$(run "$r" notes/specs notes/plans)"

r=$(new_repo)
doc "$r" "$S/K.md" "# K: x"
check "phase, none" K1 "$(run "$r" --phase K)"

r=$(new_repo)
doc "$r" "$P/K1.md" "# K1: x"
doc "$r" "$S/K3.md" "# K3: x"
check "phase, docs" K4 "$(run "$r" --phase K)"

r=$(new_repo)
mkdir -p "$r/.superpowers/chain/K"
printf '%s\n' '{"umbrella":"docs/superpowers/specs/K.md","base":"main","phases":[{"id":"K1"},{"id":"K2a"},{"id":"K2b"}]}' \
  >"$r/.superpowers/chain/K/effort.json"
check "phase, record" K3 "$(run "$r" --phase K)"

r=$(new_repo)
doc "$r" "$P/KA9.md" "# KA9: x"
check "phase, other letter ignored" K1 "$(run "$r" --phase K)"

r=$(new_repo)
doc "$r" "$S/A.md" "# A: x"
doc "$r" "$S/B.md" "# B: x"
commit_all "$r" specs
git -C "$r" rm -q "$S/B.md"
git -C "$r" commit -q -m "drop B"
check "deleted highest letter stays retired" C "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/K.md" "# K: x"
doc "$r" "$P/K1.md" "# K1: x"
commit_all "$r" plan
git -C "$r" rm -q "$P/K1.md"
git -C "$r" commit -q -m "drop K1"
check "phase, deleted plan stays retired" K2 "$(run "$r" --phase K)"

r=$(new_repo)
printf '%s\n' '# K: x' '' '## Phases' '' '### K1: One' '' '### K2: Two' '' '- **Merged from:** K3' >"$r/$S/K.md"
mkdir -p "$r/.superpowers/chain/K"
printf '%s\n' '{"phases":[{"id":"K1"},{"id":"K2"}]}' >"$r/.superpowers/chain/K/effort.json"
check "phase, merged-away id stays retired" K4 "$(run "$r" --phase K)"

r=$(new_repo)
doc "$r" "$S/A.md" "# A: x"
doc "$r" "$S/B.md" "# Retry design"
check "letter whose file exists is skipped" C "$(run "$r")"

r=$(new_repo)
doc "$r" "$S/A.md" "# A: x"
doc "$r" "$P/A1.md" "# Some plan"
check "phase whose file exists is skipped" A2 "$(run "$r" --phase A)"

plain="$ROOT/plain"
mkdir -p "$plain"
rc=0
(cd "$plain" && GIT_CEILING_DIRECTORIES="$ROOT" bash "$NEXT" >/dev/null 2>&1) || rc=$?
check "outside a repo exits 2" 2 "$rc"

r=$(new_repo)
rc=0
run "$r" --phase >/dev/null 2>&1 || rc=$?
check "--phase with no letter exits 2" 2 "$rc"

if ((failures)); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "All next-spec-id tests passed"
