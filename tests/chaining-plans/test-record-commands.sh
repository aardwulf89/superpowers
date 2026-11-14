#!/usr/bin/env bash
# Tests skills/chaining-plans/scripts/record.py, the record's commands,
# against fixture git repos.
#
# Usage: tests/chaining-plans/test-record-commands.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/chaining-plans/scripts/record.py"

failures=0
pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; failures=$((failures + 1)); }
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1: expected '$2', got '$3'"; fi
}
record() { python3 "$SCRIPT" "$@"; }

if [[ ! -f "$SCRIPT" ]]; then
  echo "[FAIL] $SCRIPT does not exist" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

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
  local rec="$dir/effort.json"
  jq -n --argjson ph "$phase" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"K1"}]}' > "$rec"
  (cd "$dir" && record phase-state "$rec" K1)
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
  "$(cd "$R" && record chain-dir)"
check "chain-dir in a linked worktree" "$R/.superpowers/chain" \
  "$(cd "$TMP/chain-wt" && record chain-dir)"
check "chain-dir from a subdirectory of a linked worktree" "$R/.superpowers/chain" \
  "$(mkdir -p "$TMP/chain-wt/sub" && cd "$TMP/chain-wt/sub" && record chain-dir)"

# chain-dir and open-efforts outside a git repo: print nothing, fail
NOREPO="$TMP/norepo"
mkdir -p "$NOREPO"
for name in chain-dir open-efforts; do
  st=0
  out=$(cd "$NOREPO" && export GIT_CEILING_DIRECTORIES="$TMP" && record "$name" 2>/dev/null) || st=$?
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
jq -n --argjson ph "$open" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"K1"}]}' > "$TMP/s-one.json"
st=0; out=$(cd "$R" && record phase-state "$TMP/s-one.json" K9 2>/dev/null) || st=$?
check "phase-state refuses an unknown id" "1:" "$st:$out"

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
run_pick() { (cd "$R" && record pick "$1"); }

# R still has b-fin merged and deleted, so branch "b-fin" is done.
R="$TMP/fin"
write_rec "$TMP/pick1.json" "$(phase K1 known '"b-fin"' '[]')" "$(phase K2 known null '["K1"]')"
check "pick returns the first startable phase" "id:K2" "$(run_pick "$TMP/pick1.json")"
write_rec "$TMP/pick2.json" "$(phase K1 dropped null '[]')" "$(phase K2 known null '["K1"]')"
check "pick blocks on a dropped dependency" "blocked:K2" "$(run_pick "$TMP/pick2.json")"
write_rec "$TMP/pick3.json" "$(phase K1 known '"b-fin"' '[]')"
check "pick with everything done" none "$(run_pick "$TMP/pick3.json")"
write_rec "$TMP/pick4.json" "$(phase K1 known null '[]')" "$(phase K2 known null '["K1"]')"
check "pick takes a phase with no dependencies" "id:K1" "$(run_pick "$TMP/pick4.json")"
write_rec "$TMP/pick5.json" "$(phase x dropped null '[]')" "$(phase picked known null '["x"]')"
check "pick blocks on a phase whose id is 'picked'" "blocked:picked" "$(run_pick "$TMP/pick5.json")"

CD="$TMP/chains"
write_rec "$CD/e1/effort.json" "$(phase K1 known null '[]')"
write_rec "$CD/e2/effort.json" "$(phase K1 known '"b-fin"' '[]')" "$(phase K2 known null '["K1"]')"
write_rec "$CD/e3/effort.json" "$(phase K1 known '"b-fin"' '[]')"
write_rec "$CD/e4/effort.json" "$(phase K1 dropped null '[]')" "$(phase K2 known '"b-fin"' '[]')"
check "open-efforts lists only efforts with open phases" \
  "$CD/e1/effort.json
$CD/e2/effort.json" \
  "$(cd "$R" && record open-efforts --chain-dir "$CD")"

# open-efforts without --chain-dir finds the repo's own chain dir
mkdir -p "$R/.superpowers"
cp -r "$CD" "$R/.superpowers/chain"
check "open-efforts defaults its chain dir" \
  "$R/.superpowers/chain/e1/effort.json
$R/.superpowers/chain/e2/effort.json" \
  "$(cd "$R" && record open-efforts)"

# get and questions
S="$TMP/set.json"
write_rec "$S" "$(phase K1 known null '[]')" "$(phase K2 known null '["K1"]')"
check "get prints one field" '["K1"]' "$(record get "$S" K2 depends_on)"
check "get prints the whole phase" "$(jq -c '.phases[1]' "$S")" "$(record get "$S" K2)"
st=0; out=$(record get "$S" K9 2>/dev/null) || st=$?
check "get refuses an unknown id" "1:" "$st:$out"
st=0; out=$(record get "$S" K2 brnch 2>/dev/null) || st=$?
check "get refuses an unknown field" "1:" "$st:$out"
Q="$TMP/questions.json"
write_rec "$Q" "$(phase K1 known null '[]')" \
  "$(phase K2 waiting null '["K1"]' | jq -c '.waits_on = [{"from":"K1","question":"Which?"}]')"
check "questions lists what a phase must answer" '[{"phase":"K2","q":["Which?"]}]' \
  "$(record questions "$Q" K1)"
check "questions with none" '[]' "$(record questions "$Q" K2)"

# refuses NAME FILE COMMAND...: COMMAND fails, FILE is unchanged, and no FILE.tmp is left.
refuses() {
  local name="$1" file="$2"; shift 2
  local before; before="$(cat "$file" 2>/dev/null || echo MISSING)"
  if "$@" 2>/dev/null; then fail "$name: command succeeded"
  elif [[ "$(cat "$file" 2>/dev/null || echo MISSING)" != "$before" ]]; then fail "$name: file changed"
  elif [[ -e "$file.tmp" ]]; then fail "$name: .tmp left"
  else pass "$name"; fi
}

# set
before="$(jq -c '.phases[0]' "$S")"
record set "$S" K2 branch --value '"K2"'
check "set changes the named phase" '"K2"' "$(jq -c '.phases[1].branch' "$S")"
check "set leaves other phases alone" "$before" "$(jq -c '.phases[0]' "$S")"
if jq -e . "$S" >/dev/null; then pass "set leaves valid JSON"; else fail "set leaves valid JSON"; fi
if [[ ! -e "$S.tmp" ]]; then pass "set leaves no .tmp file"; else fail "set leaves no .tmp file"; fi
refuses "set refuses an unknown id" "$S" record set "$S" K9 branch --value '"x"'
refuses "set refuses an unknown field" "$S" record set "$S" K1 brnch --value '"x"'
refuses "set refuses a value that is not JSON" "$S" record set "$S" K1 branch --value 'not json'

# set-closing-key, value files, and records that cannot be written
printf '%s' '["it'\''s \"done\" — café"]' > "$TMP/v.json"
record set-closing-key "$S" K1 rulings append --value-file "$TMP/v.json"
check "set-closing-key starts a null closing" \
  '{"rulings":["it'\''s \"done\" — café"],"unfinished":[],"learned":null,"replan":null}' \
  "$(jq -c '.phases[0].closing' "$S")"
record set-closing-key "$S" K1 rulings append --value '["b"]'
check "append extends" '["it'\''s \"done\" — café","b"]' "$(jq -c '.phases[0].closing.rulings' "$S")"
record set-closing-key "$S" K1 learned append --value '["x"]'
check "append to a null key" '["x"]' "$(jq -c '.phases[0].closing.learned' "$S")"
record set-closing-key "$S" K1 replan replace --value '[]'
check "replace keeps the other keys" '2 []' "$(jq -c '(.phases[0].closing.rulings|length), .phases[0].closing.replan' "$S" | paste -sd' ')"
refuses "set-closing-key refuses append to replan" "$S" record set-closing-key "$S" K1 replan append --value '[]'
refuses "set-closing-key refuses a value that is not a list" "$S" record set-closing-key "$S" K1 learned replace --value 'null'
refuses "set-closing-key refuses replan back to null" "$S" record set-closing-key "$S" K1 replan replace --value 'null'
refuses "set-closing-key refuses an unknown key" "$S" record set-closing-key "$S" K1 notes replace --value '[]'
refuses "set-closing-key refuses an unknown id" "$S" record set-closing-key "$S" K9 rulings append --value '[]'
refuses "set refuses a missing record" "$TMP/none/effort.json" record set "$TMP/none/effort.json" K1 branch --value '"x"'
if [[ ! -e "$TMP/none" ]]; then pass "set creates nothing for a missing record"; else fail "set creates nothing for a missing record"; fi
BAD="$TMP/bad.json"
printf '{' > "$BAD"
refuses "set refuses a malformed record" "$BAD" record set "$BAD" K1 branch --value '"x"'
if [[ "$(id -u)" -ne 0 ]]; then
  RO="$TMP/ro"
  write_rec "$RO/effort.json" "$(phase K1 known null '[]')"
  chmod a-w "$RO"
  refuses "set refuses a write that cannot complete" "$RO/effort.json" record set "$RO/effort.json" K1 branch --value '"x"'
  chmod u+w "$RO"
fi
st=0; record set "$S" K1 branch --value '"x"' --value-file "$TMP/v.json" 2>/dev/null || st=$?
check "set refuses both value forms (usage)" 2 "$st"
st=0; record set "$S" K1 branch 2>/dev/null || st=$?
check "set refuses no value (usage)" 2 "$st"
refuses "set refuses an unreadable value file" "$S" record set "$S" K1 branch --value-file "$TMP/no-such.json"
check "set --value-file round-trips text" '["it'\''s \"done\" — café"]' \
  "$(record set "$S" K2 partner_questions --value-file "$TMP/v.json" && jq -c '.phases[1].partner_questions' "$S")"
# jq -c decodes \u escapes, so pin the raw UTF-8 bytes in the file itself
if grep -qF '— café' "$S"; then pass "the record holds raw UTF-8"; else fail "the record holds raw UTF-8"; fi

# Bad input is refused with "record <sub>: <reason>", never a traceback, and
# leaves no .tmp.
refused_cleanly() { # NAME FILE SUB ARGS...: refuses, and stderr is the one-line form
  local name="$1" file="$2" sub="$3"; shift 3
  refuses "$name" "$file" record "$sub" "$@"
  local err; err=$(record "$sub" "$@" 2>&1 >/dev/null || true)
  if [[ "$err" == "record $sub: "* && "$err" != *Traceback* ]]; then pass "$name: says why"
  else fail "$name: stderr was '$err'"; fi
}
refused_cleanly "set refuses a value it cannot encode" "$S" set "$S" K1 branch --value '"\ud800"'
printf '\377' > "$TMP/latin1.json"
refused_cleanly "set refuses a value file that is not UTF-8" "$S" set "$S" K1 branch --value-file "$TMP/latin1.json"
L1="$TMP/latin1-rec.json"
printf '\377' > "$L1"
refused_cleanly "set refuses a record that is not UTF-8" "$L1" set "$L1" K1 branch --value '"x"'
for c in NaN Infinity -Infinity; do
  refused_cleanly "set refuses $c" "$S" set "$S" K1 branch "--value=$c"
done

# Every write, not only set, refuses a missing, malformed or unwritable record.
one_phase="[$(phase K1 known null '[]')]"
refuses "set-phases refuses a missing record" "$TMP/none/effort.json" \
  record set-phases "$TMP/none/effort.json" --value "$one_phase"
refuses "set-phases refuses a malformed record" "$BAD" record set-phases "$BAD" --value "$one_phase"
refuses "set-closing-key refuses a missing record" "$TMP/none/effort.json" \
  record set-closing-key "$TMP/none/effort.json" K1 rulings append --value '["x"]'
refuses "set-closing-key refuses a malformed record" "$BAD" \
  record set-closing-key "$BAD" K1 rulings append --value '["x"]'
if [[ "$(id -u)" -ne 0 ]]; then
  chmod a-w "$RO"
  refuses "set-phases refuses a write that cannot complete" "$RO/effort.json" \
    record set-phases "$RO/effort.json" --value "$one_phase"
  refuses "set-closing-key refuses a write that cannot complete" "$RO/effort.json" \
    record set-closing-key "$RO/effort.json" K1 rulings append --value '["x"]'
  chmod u+w "$RO"
fi
if [[ ! -e "$TMP/none" ]]; then pass "no write creates a missing record"; else fail "no write creates a missing record"; fi

# set-phases
P="$TMP/set-phases.json"
write_rec "$P" "$(phase K1 known null '[]')" "$(phase K2 known null '["K1"]')"
new_phases="[$(phase K1 known null '[]'),$(phase K2a known null '["K1"]'),$(phase K2b known null '["K2a"]')]"
record set-phases "$P" --value "$new_phases"
if jq -e . "$P" >/dev/null; then pass "set-phases leaves valid JSON"; else fail "set-phases leaves valid JSON"; fi
check "set-phases replaces the phases with exactly the new ones" \
  "$(jq -c . <<<"$new_phases")" "$(jq -c '.phases' "$P")"
check "set-phases keeps umbrella and base" '"u.md" "main"' "$(jq -c '.umbrella, .base' "$P" | paste -sd' ')"
if [[ ! -e "$P.tmp" ]]; then pass "set-phases leaves no .tmp file"; else fail "set-phases leaves no .tmp file"; fi
one="$(phase K1 known null '[]')"
refuses "set-phases refuses an object" "$P" record set-phases "$P" --value "$one"
refuses "set-phases refuses a phase missing a key" "$P" record set-phases "$P" \
  --value "[$(jq -c 'del(.title)' <<<"$one")]"
refuses "set-phases refuses a repeated id" "$P" record set-phases "$P" --value "[$one,$one]"

# new-record
N="$TMP/new/e/effort.json"
good="$(printf '%s\n' "$one" "$(phase K2 known null '["K1"]')" | jq -sc '{umbrella:"u.md", base:"main", phases:.}')"
record new-record "$N" --value "$good"
check "new-record writes the record it is given" "$good" "$(jq -c . "$N" 2>/dev/null || true)"
if [[ ! -e "$N.tmp" ]]; then pass "new-record leaves no .tmp file"; else fail "new-record leaves no .tmp file"; fi
refuses "new-record refuses an existing record" "$N" record new-record "$N" --value "$good"
N2="$TMP/new/e2/effort.json"
refuses "new-record refuses a record without base" "$N2" record new-record "$N2" \
  --value "$(jq -c 'del(.base)' <<<"$good")"
refuses "new-record refuses a phase with an extra key" "$N2" record new-record "$N2" \
  --value "$(jq -c '.phases[0].head = 1' <<<"$good")"
refuses "new-record refuses malformed JSON" "$N2" record new-record "$N2" --value '{'

if ((failures > 0)); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "All record command tests passed"
