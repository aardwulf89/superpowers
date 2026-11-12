#!/usr/bin/env bash
# The inputs assigned before each eval are read by the command blocks it runs.
# shellcheck disable=SC2034
# Tests the named shell commands in skills/chaining-plans/references/record.md
# against fixture git repos.
#
# Usage: tests/chaining-plans/test-record-commands.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RECORD_MD="$REPO_ROOT/skills/chaining-plans/references/record.md"

failures=0
pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; failures=$((failures + 1)); }
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1: expected '$2', got '$3'"; fi
}

# Print the body of the bash fence under "<!-- cmd: NAME -->".
cmd_block() {
  awk -v name="$1" '
    $0 == "<!-- cmd: " name " -->" { want = 1; next }
    want && /^```bash$/ { inblock = 1; next }
    inblock && /^```$/ { exit }
    inblock { print }
  ' "$RECORD_MD"
}

if [[ ! -f "$RECORD_MD" ]]; then
  echo "[FAIL] $RECORD_MD does not exist" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

for name in chain-dir open-efforts phase-state pick new-record set set-phases; do
  if [[ -z "$(cmd_block "$name")" ]]; then fail "block '$name' exists in record.md"; fi
done

# The three blocks that classify phases carry the same phase_state function.
fn() { cmd_block "$1" | awk '/^phase_state\(\) \(/ { f = 1 } f { print } f && /^\)$/ { exit }'; }
check "phase_state is identical in phase-state, pick and open-efforts" \
  "$(fn phase-state | md5sum)" "$(fn pick | md5sum)"
check "phase_state is identical in phase-state and open-efforts" \
  "$(fn phase-state | md5sum)" "$(fn open-efforts | md5sum)"

# new_repo DIR: a repo on main with docs/superpowers/plans/p.md committed.
new_repo() {
  git init -q -b main "$1"
  mkdir -p "$1/docs/superpowers/plans"
  echo plan > "$1/docs/superpowers/plans/p.md"
  git -C "$1" add -A
  git -C "$1" commit -q -m init
}

# state_of DIR PHASE_JSON: run phase-state in DIR for a one-phase record.
state_of() {
  local dir="$1" phase="$2"
  local rec="$dir/effort.json" id=p1
  jq -n --argjson ph "$phase" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"p1"}]}' > "$rec"
  (cd "$dir" && rec="$rec" id="$id" && eval "$(cmd_block phase-state)")
}

PLAN=docs/superpowers/plans/p.md
mkws() { # DIR: create the SDD workspace for plan p
  mkdir -p "$1/.superpowers/sdd/p"
  echo "$PLAN" > "$1/.superpowers/sdd/p/plan-path"
}

# chain-dir
R="$TMP/chain"
new_repo "$R"
git -C "$R" worktree add -q -b wt "$TMP/chain-wt"
check "chain-dir in the main checkout" "$R/.superpowers/chain" \
  "$(cd "$R" && eval "$(cmd_block chain-dir)")"
check "chain-dir in a linked worktree" "$R/.superpowers/chain" \
  "$(cd "$TMP/chain-wt" && eval "$(cmd_block chain-dir)")"

# chain-dir and open-efforts outside a git repo: print nothing, fail
NOREPO="$TMP/norepo"
mkdir -p "$NOREPO"
for name in chain-dir open-efforts; do
  st=0
  out=$(cd "$NOREPO" && export GIT_CEILING_DIRECTORIES="$TMP" && unset chain_dir &&
    eval "$(cmd_block "$name")" 2>/dev/null) || st=$?
  if [[ -z "$out" && $st -ne 0 ]]; then pass "$name outside a git repo prints nothing and fails"
  else fail "$name outside a git repo: printed '$out', exit $st"; fi
done

# phase-state
R="$TMP/s"
new_repo "$R"
open="{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":null,\"closing\":null}"
check "phase-state dropped" dropped \
  "$(state_of "$R" "{\"status\":\"dropped\",\"plan\":\"$PLAN\",\"branch\":\"b\",\"closing\":null}")"
check "phase-state not-started" not-started "$(state_of "$R" "$open")"

# cut-off with a worktree
git -C "$R" worktree add -q -b b-wt "$TMP/s-wt"
mkws "$TMP/s-wt"
check "phase-state cut-off in a worktree" cut-off \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-wt\",\"closing\":null}")"
check "phase-state cut-off: workspace for another plan is not this phase's" "done" \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"docs/superpowers/plans/other.md\",\"branch\":\"b-wt\",\"closing\":{\"replan\":[]}}")"
check "phase-state plan null finds no workspace" "close-missed" \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":null,\"branch\":\"b-wt\",\"closing\":null}")"

# cut-off in place: branch checked out in the main checkout
R="$TMP/inplace"
new_repo "$R"
git -C "$R" checkout -q -b b-in
mkws "$R"
check "phase-state cut-off in place" cut-off \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-in\",\"closing\":null}")"

# finished: a commit not on main, no workspace
R="$TMP/fin"
new_repo "$R"
git -C "$R" checkout -q -b b-fin
echo x > "$R/x"; git -C "$R" add x; git -C "$R" commit -q -m x
git -C "$R" checkout -q main
check "phase-state finished-unclosed" finished-unclosed \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-fin\",\"closing\":null}")"
check "phase-state closed-unmerged" closed-unmerged \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-fin\",\"closing\":{\"replan\":[]}}")"

# merged and deleted
git -C "$R" merge -q --no-ff b-fin -m merge
git -C "$R" branch -q -d b-fin
check "phase-state close-missed" close-missed \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-fin\",\"closing\":null}")"
check "phase-state done" "done" \
  "$(state_of "$R" "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-fin\",\"closing\":{\"replan\":[]}}")"

# merged through a PR (a squash: the branch is not an ancestor): gh says so
R="$TMP/gh"
new_repo "$R"
git -C "$R" checkout -q -b b-sq
echo y > "$R/y"; git -C "$R" add y; git -C "$R" commit -q -m y
git -C "$R" checkout -q main
mkdir -p "$TMP/ghbin"
printf '#!/bin/sh\necho "$GH_STATE"\n' > "$TMP/ghbin/gh"
chmod +x "$TMP/ghbin/gh"
sq() { # GH_STATE CLOSING_JSON
  PATH="$TMP/ghbin:$PATH" GH_STATE="$1" state_of "$R" \
    "{\"status\":\"known\",\"plan\":\"$PLAN\",\"branch\":\"b-sq\",\"closing\":$2}"
}
check "phase-state close-missed when gh says MERGED" close-missed "$(sq MERGED null)"
check "phase-state done when gh says MERGED" "done" "$(sq MERGED '{"replan":[]}')"
check "phase-state finished-unclosed when gh says OPEN" finished-unclosed "$(sq OPEN null)"

# pick and open-efforts
phase() { # id status branch depends_on_json -> JSON, all ten keys; a set branch means done
  local closing=null
  [[ "$3" != null ]] && closing='{"replan":[]}'
  echo "{\"id\":\"$1\",\"title\":\"$1\",\"status\":\"$2\",\"depends_on\":$4,\"waits_on\":[],\"partner_questions\":[],\"spec\":null,\"plan\":\"$PLAN\",\"branch\":$3,\"closing\":$closing}"
}
write_rec() { # file phase_json...
  local f="$1"; shift
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$@" | jq -s '{umbrella:"u.md", base:"main", phases:.}' > "$f"
}
run_pick() { (cd "$R" && rec="$1" && eval "$(cmd_block pick)"); }

# R still has b-fin merged and deleted, so branch "b-fin" is done.
write_rec "$TMP/pick1.json" "$(phase p1 known '"b-fin"' '[]')" "$(phase p2 known null '["p1"]')"
check "pick returns the first startable phase" "id:p2" "$(run_pick "$TMP/pick1.json")"
write_rec "$TMP/pick2.json" "$(phase p1 dropped null '[]')" "$(phase p2 known null '["p1"]')"
check "pick blocks on a dropped dependency" "blocked:p2" "$(run_pick "$TMP/pick2.json")"
write_rec "$TMP/pick3.json" "$(phase p1 known '"b-fin"' '[]')"
check "pick with everything done" none "$(run_pick "$TMP/pick3.json")"
write_rec "$TMP/pick4.json" "$(phase p1 known null '[]')" "$(phase p2 known null '["p1"]')"
check "pick takes a phase with no dependencies" "id:p1" "$(run_pick "$TMP/pick4.json")"
write_rec "$TMP/pick5.json" "$(phase x dropped null '[]')" "$(phase picked known null '["x"]')"
check "pick blocks on a phase whose id is 'picked'" "blocked:picked" "$(run_pick "$TMP/pick5.json")"

CD="$TMP/chains"
write_rec "$CD/e1/effort.json" "$(phase p1 known null '[]')"
write_rec "$CD/e2/effort.json" "$(phase p1 known '"b-fin"' '[]')" "$(phase p2 known null '["p1"]')"
write_rec "$CD/e3/effort.json" "$(phase p1 known '"b-fin"' '[]')"
write_rec "$CD/e4/effort.json" "$(phase p1 dropped null '[]')" "$(phase p2 known '"b-fin"' '[]')"
check "open-efforts lists only efforts with open phases" \
  "$CD/e1/effort.json
$CD/e2/effort.json" \
  "$(cd "$R" && chain_dir="$CD" && eval "$(cmd_block open-efforts)")"

# open-efforts with chain_dir unset finds the repo's own chain dir
mkdir -p "$R/.superpowers"
cp -r "$CD" "$R/.superpowers/chain"
check "open-efforts defaults chain_dir when unset" \
  "$R/.superpowers/chain/e1/effort.json
$R/.superpowers/chain/e2/effort.json" \
  "$(cd "$R" && unset chain_dir && eval "$(cmd_block open-efforts)")"

# set
S="$TMP/set.json"
write_rec "$S" "$(phase p1 known null '[]')" "$(phase p2 known null '["p1"]')"
before="$(jq -c '.phases[0]' "$S")"
(rec="$S" id=p2 field=branch value_json='"p2"' && eval "$(cmd_block set)")
check "set changes the named phase" '"p2"' "$(jq -c '.phases[1].branch' "$S")"
check "set leaves other phases alone" "$before" "$(jq -c '.phases[0]' "$S")"
if jq -e . "$S" >/dev/null; then pass "set leaves valid JSON"; else fail "set leaves valid JSON"; fi
if [[ ! -e "$S.tmp" ]]; then pass "set leaves no .tmp file"; else fail "set leaves no .tmp file"; fi
# refuses NAME FILE BLOCK ASSIGNMENT...: with the assignments made, BLOCK fails, FILE is
# unchanged, and no .tmp is left.
refuses() {
  local name="$1" file="$2" block="$3"; shift 3
  local before; before="$(cat "$file" 2>/dev/null || echo MISSING)"
  if (eval "$*" && eval "$(cmd_block "$block")") 2>/dev/null; then fail "$name: block succeeded"
  elif [[ "$(cat "$file" 2>/dev/null || echo MISSING)" != "$before" ]]; then fail "$name: file changed"
  elif [[ -e "$file.tmp" ]]; then fail "$name: .tmp left"
  else pass "$name"; fi
}
refuses "set refuses an unknown id" "$S" set rec="$S" id=p9 field=branch "value_json='\"x\"'"
refuses "set refuses an unknown field" "$S" set rec="$S" id=p1 field=brnch "value_json='\"x\"'"
refuses "set refuses a value that is not JSON" "$S" set rec="$S" id=p1 field=branch "value_json='not json'"

# set-phases
P="$TMP/set-phases.json"
write_rec "$P" "$(phase p1 known null '[]')" "$(phase p2 known null '["p1"]')"
new_phases="[$(phase p1 known null '[]'),$(phase p2a known null '["p1"]'),$(phase p2b known null '["p2a"]')]"
(rec="$P" phases_json="$new_phases" && eval "$(cmd_block set-phases)")
if jq -e . "$P" >/dev/null; then pass "set-phases leaves valid JSON"; else fail "set-phases leaves valid JSON"; fi
check "set-phases replaces the phases with exactly the new ones" \
  "$(jq -c . <<<"$new_phases")" "$(jq -c '.phases' "$P")"
check "set-phases keeps umbrella and base" '"u.md" "main"' "$(jq -c '.umbrella, .base' "$P" | paste -sd' ')"
if [[ ! -e "$P.tmp" ]]; then pass "set-phases leaves no .tmp file"; else fail "set-phases leaves no .tmp file"; fi
one="$(phase p1 known null '[]')"
refuses "set-phases refuses an object" "$P" set-phases rec="$P" "phases_json='$one'"
refuses "set-phases refuses a phase missing a key" "$P" set-phases rec="$P" \
  "phases_json='[$(jq -c 'del(.title)' <<<"$one")]'"
refuses "set-phases refuses a repeated id" "$P" set-phases rec="$P" "phases_json='[$one,$one]'"

# new-record
N="$TMP/new/e/effort.json"
good="$(printf '%s\n' "$one" "$(phase p2 known null '["p1"]')" | jq -sc '{umbrella:"u.md", base:"main", phases:.}')"
(rec="$N" record_json="$good" && eval "$(cmd_block new-record)")
check "new-record writes the record it is given" "$good" "$(jq -c . "$N" 2>/dev/null || true)"
if [[ ! -e "$N.tmp" ]]; then pass "new-record leaves no .tmp file"; else fail "new-record leaves no .tmp file"; fi
refuses "new-record refuses an existing record" "$N" new-record rec="$N" "record_json='$good'"
N2="$TMP/new/e2/effort.json"
refuses "new-record refuses a record without base" "$N2" new-record rec="$N2" \
  "record_json='$(jq -c 'del(.base)' <<<"$good")'"
refuses "new-record refuses a phase with an extra key" "$N2" new-record rec="$N2" \
  "record_json='$(jq -c '.phases[0].head = 1' <<<"$good")'"
refuses "new-record refuses malformed JSON" "$N2" new-record rec="$N2" "record_json='{'"

if ((failures > 0)); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "All record command tests passed"
