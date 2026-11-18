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

# state_of DIR PHASE_JSON: run phase-state in DIR for a one-phase record
# whose phase is K1.
state_of() {
  local dir="$1" phase="$2"
  local rec="$TMP/state-of.json"
  jq -n --argjson ph "$phase" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"K1"}]}' > "$rec"
  (cd "$dir" && record phase-state "$rec" K1)
}

PLAN=docs/superpowers/plans/p.md
mkws() { # DIR: create the SDD workspace for plan p
  mkdir -p "$1/.superpowers/sdd/p"
  echo "$PLAN" > "$1/.superpowers/sdd/p/plan-path"
}
# build_on DIR BRANCH [ID]: on BRANCH (made from main), commit the build
# results file of phase ID (default K1); back on main after.
build_on() {
  local id="${3:-K1}"
  git -C "$1" checkout -q -b "$2" main
  echo '{"rulings":[],"unfinished":[]}' > "$1/docs/superpowers/plans/$id.build.json"
  echo "$2" > "$1/work-$2"
  git -C "$1" add -A
  git -C "$1" commit -q -m "build $id on $2"
  git -C "$1" checkout -q main
}
advance_main() { # DIR: a commit on main that no phase branch has
  echo "$RANDOM" > "$1/elsewhere"
  git -C "$1" add -A
  git -C "$1" commit -q -m elsewhere
}
open='{"status":"known","plan":"'$PLAN'","closing":null}'
closed='{"status":"known","plan":"'$PLAN'","closing":{"replan":[]}}'

# open-efforts outside a git repo: prints nothing, fails
NOREPO="$TMP/norepo"
mkdir -p "$NOREPO"
st=0
out=$(cd "$NOREPO" && export GIT_CEILING_DIRECTORIES="$TMP" && record open-efforts 2>/dev/null) || st=$?
if [[ -z "$out" && $st -ne 0 ]]; then pass "open-efforts outside a git repo prints nothing and fails"
else fail "open-efforts outside a git repo: printed '$out', exit $st"; fi
st=0; record chain-dir >/dev/null 2>&1 || st=$?
check "chain-dir is gone (usage error)" 2 "$st"

# phase-state: dropped, not-started, unknown id
R="$TMP/s"
new_repo "$R"
check "phase-state dropped" dropped \
  "$(state_of "$R" '{"status":"dropped","plan":"'$PLAN'","closing":null}')"
check "phase-state not-started" not-started "$(state_of "$R" "$open")"
jq -n --argjson ph "$open" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"K1"}]}' > "$TMP/s-one.json"
st=0; out=$(cd "$R" && record phase-state "$TMP/s-one.json" K9 2>/dev/null) || st=$?
check "phase-state refuses an unknown id" "1:" "$st:$out"

# cut-off: a workspace for the plan in a linked worktree, or in the main checkout
git -C "$R" worktree add -q -b worktree-K1 "$TMP/s-wt"
check "phase-state: a phase branch with no commits of its own is not-started" not-started \
  "$(state_of "$R" "$open")"
mkws "$TMP/s-wt"
check "phase-state cut-off in a linked worktree" cut-off "$(state_of "$R" "$open")"
check "phase-state cut-off from inside that worktree" cut-off "$(state_of "$TMP/s-wt" "$open")"
check "phase-state: a workspace for another plan is not this phase's" not-started \
  "$(state_of "$R" '{"status":"known","plan":"docs/superpowers/plans/other.md","closing":null}')"
check "phase-state: plan null finds no workspace" not-started \
  "$(state_of "$R" '{"status":"known","plan":null,"closing":null}')"
R="$TMP/inplace"
new_repo "$R"
mkws "$R"
check "phase-state cut-off in the main checkout" cut-off "$(state_of "$R" "$open")"

# merged: the results file is on base, whatever the merge style
R="$TMP/merge"; new_repo "$R"; build_on "$R" worktree-K1; advance_main "$R"
git -C "$R" merge -q --no-ff worktree-K1 -m merge
check "phase-state close-missed after a merge commit" close-missed "$(state_of "$R" "$open")"
check "phase-state done after a merge commit" "done" "$(state_of "$R" "$closed")"
git -C "$R" branch -q -d worktree-K1
check "phase-state done with the branch deleted" "done" "$(state_of "$R" "$closed")"
mkws "$R"
check "phase-state: a workspace wins over results on base" cut-off "$(state_of "$R" "$closed")"

R="$TMP/ff"; new_repo "$R"; build_on "$R" worktree-K1
git -C "$R" merge -q --ff-only worktree-K1
check "phase-state close-missed after a fast-forward" close-missed "$(state_of "$R" "$open")"

R="$TMP/squash"; new_repo "$R"; build_on "$R" worktree-K1; advance_main "$R"
git -C "$R" merge -q --squash worktree-K1 >/dev/null 2>&1
git -C "$R" commit -q -m squash
check "phase-state close-missed after a squash (branch kept)" close-missed "$(state_of "$R" "$open")"
git -C "$R" branch -q -D worktree-K1
check "phase-state close-missed after a squash (branch deleted)" close-missed "$(state_of "$R" "$open")"

R="$TMP/rebase"; new_repo "$R"; build_on "$R" worktree-K1; advance_main "$R"
git -C "$R" cherry-pick worktree-K1 >/dev/null
check "phase-state close-missed after a rebase onto base" close-missed "$(state_of "$R" "$open")"

# finished, not merged: the results file is on the phase branch only
R="$TMP/fin"; new_repo "$R"; build_on "$R" worktree-K1
check "phase-state finished-unclosed" finished-unclosed "$(state_of "$R" "$open")"
check "phase-state closed-unmerged" closed-unmerged "$(state_of "$R" "$closed")"
R="$TMP/fin-inplace"; new_repo "$R"; build_on "$R" K1
check "phase-state finished-unclosed, built in place" finished-unclosed "$(state_of "$R" "$open")"

# a discard: the branch is gone, its results never reached base
R="$TMP/discard"; new_repo "$R"; build_on "$R" worktree-K1
git -C "$R" branch -q -D worktree-K1
check "phase-state: a branch deleted unmerged is not-started" not-started "$(state_of "$R" "$open")"

# anomaly: commits with no workspace and no results, or both branch names
R="$TMP/anomaly"; new_repo "$R"
git -C "$R" checkout -q -b worktree-K1
echo x > "$R/x"; git -C "$R" add x; git -C "$R" commit -q -m x
git -C "$R" checkout -q main
check "phase-state anomaly: commits, no workspace, no results" anomaly "$(state_of "$R" "$open")"
R="$TMP/both"; new_repo "$R"; build_on "$R" worktree-K1
git -C "$R" branch -q K1 main
check "phase-state anomaly: both branch names exist" anomaly "$(state_of "$R" "$open")"
jq -n --argjson ph "$open" '{umbrella:"u.md", base:"main", phases:[$ph + {id:"K1"}]}' > "$TMP/anomaly.json"
check "pick blocks on an anomaly" "blocked:K1" "$(cd "$TMP/anomaly" && record pick "$TMP/anomaly.json")"

# a record whose base has no local branch: refuse, never read not-started
# (Build would then reset the phase branch to base and lose its commits)
jq -n --argjson ph "$open" '{umbrella:"u.md", base:"mian", phases:[$ph + {id:"K1"}]}' > "$TMP/nobase.json"
st=0; out=$(cd "$TMP/anomaly" && record phase-state "$TMP/nobase.json" K1 2>"$TMP/nobase.err") || st=$?
check "phase-state refuses a base with no local branch" "1:" "$st:$out"
if grep -q "record phase-state: no branch 'mian'" "$TMP/nobase.err"; then pass "phase-state names the missing base"
else fail "phase-state names the missing base: $(cat "$TMP/nobase.err")"; fi

# pick and open-efforts. RD has results on main for K1, K2 and K3, so a
# phase with one of those ids and a replan is done; other ids are not started.
RD="$TMP/done"
new_repo "$RD"
for id in K1 K2 K3; do build_on "$RD" "worktree-$id" "$id"; git -C "$RD" merge -q --no-ff "worktree-$id" -m "merge $id"; done
phase() { # id status closed|open depends_on_json [unfinished_json] -> JSON, all nine keys
  local closing=null unfinished="${5:-}"
  if [[ "$3" == closed ]]; then
    closing='{"replan":[]}'
    [[ -n "$unfinished" ]] && closing="{\"replan\":[],\"unfinished\":$unfinished}"
  elif [[ -n "$unfinished" ]]; then
    closing="{\"unfinished\":$unfinished}"
  fi
  echo "{\"id\":\"$1\",\"title\":\"$1\",\"status\":\"$2\",\"depends_on\":$4,\"waits_on\":[],\"partner_questions\":[],\"spec\":null,\"plan\":\"$PLAN\",\"closing\":$closing}"
}
write_rec() { # file phase_json...
  local f="$1"; shift
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$@" | jq -s '{umbrella:"u.md", base:"main", phases:.}' > "$f"
}
R="$RD"
run_pick() { (cd "$R" && record pick "$1"); }

write_rec "$TMP/pick1.json" "$(phase K1 known closed '[]')" "$(phase K4 known open '["K1"]')"
check "pick returns the first startable phase" "id:K4" "$(run_pick "$TMP/pick1.json")"
write_rec "$TMP/pick2.json" "$(phase K4 dropped open '[]')" "$(phase K5 known open '["K4"]')"
check "pick blocks on a dropped dependency" "blocked:K5" "$(run_pick "$TMP/pick2.json")"
write_rec "$TMP/pick3.json" "$(phase K1 known closed '[]')"
check "pick with everything done" none "$(run_pick "$TMP/pick3.json")"
write_rec "$TMP/pick4.json" "$(phase K4 known open '[]')" "$(phase K5 known open '["K4"]')"
check "pick takes a phase with no dependencies" "id:K4" "$(run_pick "$TMP/pick4.json")"
write_rec "$TMP/pick5.json" "$(phase x dropped open '[]')" "$(phase picked known open '["x"]')"
check "pick blocks on a phase whose id is 'picked'" "blocked:picked" "$(run_pick "$TMP/pick5.json")"
write_rec "$TMP/pick6.json" "$(phase K1 known open '[]')"
check "pick: results on base with no replan is a missed close, not done" "blocked:K1" "$(run_pick "$TMP/pick6.json")"

# pick: items and none
write_rec "$TMP/pn.json" "$(phase K1 known closed '[]' '[]')"
check "pick on a done record with no item" none "$(run_pick "$TMP/pn.json")"
write_rec "$TMP/pi.json" "$(phase K1 known closed '[]' '["Partner item: x. Default: as is."]')"
check "pick on a done record with an open item" items "$(run_pick "$TMP/pi.json")"
for suffix in ' [settled: K1]' ' [dropped]' ' [carried]' ' [adopted by M2]'; do
  write_rec "$TMP/ps.json" "$(phase K1 known closed '[]' "$(jq -nc --arg s "$suffix" '["Partner item: x. Default: as is." + $s]')")"
  check "pick: the suffix '$suffix' closes an item" none "$(run_pick "$TMP/ps.json")"
done
write_rec "$TMP/pd.json" "$(phase K4 dropped open '[]' '["Partner item: x. Default: as is."]')"
check "pick: an open item in a dropped phase" items "$(run_pick "$TMP/pd.json")"
write_rec "$TMP/pq.json" "$(phase K1 known closed '[]' '["Partner item: keep \"[carried]\" as the word? Default: as is."]')"
check "pick: a suffix that is not at the end leaves the item open" items "$(run_pick "$TMP/pq.json")"
write_rec "$TMP/pz.json" "$(phase K4 dropped open '[]')" \
  "$(phase K2 known closed '[]')" \
  "$(phase K3 known closed '[]' null)"
st=0; out=$(run_pick "$TMP/pz.json" 2>&1) || st=$?
check "pick with no closing, no unfinished and a null unfinished" "0:none" "$st:$out"
NI="$TMP/niche"
mkdir -p "$NI"; cp "$TMP/pz.json" "$NI/E.json"
st=0; out=$(cd "$R" && record open-efforts --efforts-dir "$NI" 2>&1) || st=$?
check "open-efforts lists nothing for it, and says nothing" "0:" "$st:$out"
st=0; out=$(cd "$R" && record carried --efforts-dir "$NI" 2>&1) || st=$?
check "carried lists nothing for it, and says nothing" "0:[]" "$st:$out"
write_rec "$TMP/po.json" "$(phase K4 known open '[]' '["Partner item: x. Default: as is."]')"
check "pick: the open phase wins over an open item" "id:K4" "$(run_pick "$TMP/po.json")"

# open-efforts with partner items, and carried
CI="$TMP/items"
write_rec "$CI/A.json" "$(phase K4 known open '[]')"
write_rec "$CI/B.json" "$(phase K1 known closed '[]' '["Partner item: x. Default: as is."]')"
write_rec "$CI/C.json" "$(phase K1 known closed '[]' '[]')"
printf '{' > "$CI/D.json"
st=0; out=$(cd "$R" && record open-efforts --efforts-dir "$CI" 2>"$TMP/oe.err") || st=$?
check "open-efforts lists open phases and open items" "0:$CI/A.json
$CI/B.json" "$st:$out"
if grep -q "$CI/D.json" "$TMP/oe.err"; then pass "open-efforts names the unreadable record"; else fail "open-efforts names the unreadable record"; fi

CC="$TMP/carried"
write_rec "$CC/A.json" "$(phase K1 known closed '[]' '[]')" \
  "$(phase K2 known closed '[]' '["none", "Partner item: a [carried]", "Partner item: b [dropped]"]')"
write_rec "$CC/B.json" "$(phase K1 known closed '[]' '["Partner item: c [carried]"]')"
want='[{"record":"'$CC'/A.json","phase":"K2","index":1,"item":"Partner item: a [carried]"},{"record":"'$CC'/B.json","phase":"K1","index":0,"item":"Partner item: c [carried]"}]'
check "carried lists each carried line" "$want" "$(cd "$R" && record carried --efforts-dir "$CC")"
printf '{' > "$CC/C.json"
st=0; out=$(cd "$R" && record carried --efforts-dir "$CC" 2>"$TMP/c.err") || st=$?
check "carried skips an unreadable record" "0:$want" "$st:$out"
if grep -q "$CC/C.json" "$TMP/c.err"; then pass "carried names the unreadable record"; else fail "carried names the unreadable record"; fi

CD="$TMP/chains"
write_rec "$CD/A.json" "$(phase K4 known open '[]')"
write_rec "$CD/B.json" "$(phase K1 known closed '[]')" "$(phase K4 known open '["K1"]')"
write_rec "$CD/C.json" "$(phase K1 known closed '[]')"
write_rec "$CD/D.json" "$(phase K4 dropped open '[]')" "$(phase K2 known closed '[]')"
check "open-efforts lists only efforts with open phases" \
  "$CD/A.json
$CD/B.json" \
  "$(cd "$R" && record open-efforts --efforts-dir "$CD")"

# open-efforts without --efforts-dir finds the repo's own efforts directory,
# the same from a linked worktree
mkdir -p "$R/docs/superpowers/efforts"
cp "$CD"/*.json "$R/docs/superpowers/efforts/"
check "open-efforts defaults its efforts dir" \
  "$R/docs/superpowers/efforts/A.json
$R/docs/superpowers/efforts/B.json" \
  "$(cd "$R" && record open-efforts)"
git -C "$R" worktree add -q -b side "$TMP/done-wt"
check "open-efforts finds the main checkout's efforts from a linked worktree" \
  "$R/docs/superpowers/efforts/A.json
$R/docs/superpowers/efforts/B.json" \
  "$(cd "$TMP/done-wt" && record open-efforts)"

# get and questions
S="$TMP/set.json"
write_rec "$S" "$(phase K1 known open '[]')" "$(phase K2 known open '["K1"]')"
check "get prints one field" '["K1"]' "$(record get "$S" K2 depends_on)"
check "get prints the whole phase" "$(jq -c '.phases[1]' "$S")" "$(record get "$S" K2)"
st=0; out=$(record get "$S" K9 2>/dev/null) || st=$?
check "get refuses an unknown id" "1:" "$st:$out"
st=0; out=$(record get "$S" K2 brnch 2>/dev/null) || st=$?
check "get refuses an unknown field" "1:" "$st:$out"
Q="$TMP/questions.json"
write_rec "$Q" "$(phase K1 known open '[]')" \
  "$(phase K2 waiting open '["K1"]' | jq -c '.waits_on = [{"from":"K1","question":"Which?"}]')"
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
record set "$S" K2 title --value '"Second"'
check "set changes the named phase" '"Second"' "$(jq -c '.phases[1].title' "$S")"
check "set leaves other phases alone" "$before" "$(jq -c '.phases[0]' "$S")"
if jq -e . "$S" >/dev/null; then pass "set leaves valid JSON"; else fail "set leaves valid JSON"; fi
if [[ ! -e "$S.tmp" ]]; then pass "set leaves no .tmp file"; else fail "set leaves no .tmp file"; fi
refuses "set refuses an unknown id" "$S" record set "$S" K9 branch --value '"x"'
refuses "set refuses an unknown field" "$S" record set "$S" K1 brnch --value '"x"'
refuses "set refuses the removed branch field" "$S" record set "$S" K1 branch --value '"x"'
refuses "set refuses a value that is not JSON" "$S" record set "$S" K1 title --value 'not json'

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
refuses "set refuses a missing record" "$TMP/none/effort.json" record set "$TMP/none/effort.json" K1 title --value '"x"'
if [[ ! -e "$TMP/none" ]]; then pass "set creates nothing for a missing record"; else fail "set creates nothing for a missing record"; fi
BAD="$TMP/bad.json"
printf '{' > "$BAD"
refuses "set refuses a malformed record" "$BAD" record set "$BAD" K1 title --value '"x"'
if [[ "$(id -u)" -ne 0 ]]; then
  RO="$TMP/ro"
  write_rec "$RO/effort.json" "$(phase K1 known open '[]')"
  chmod a-w "$RO"
  refuses "set refuses a write that cannot complete" "$RO/effort.json" record set "$RO/effort.json" K1 title --value '"x"'
  chmod u+w "$RO"
fi
st=0; record set "$S" K1 title --value '"x"' --value-file "$TMP/v.json" 2>/dev/null || st=$?
check "set refuses both value forms (usage)" 2 "$st"
st=0; record set "$S" K1 title 2>/dev/null || st=$?
check "set refuses no value (usage)" 2 "$st"
refuses "set refuses an unreadable value file" "$S" record set "$S" K1 title --value-file "$TMP/no-such.json"
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
refused_cleanly "set refuses a value it cannot encode" "$S" set "$S" K1 title --value '"\ud800"'
printf '\377' > "$TMP/latin1.json"
refused_cleanly "set refuses a value file that is not UTF-8" "$S" set "$S" K1 title --value-file "$TMP/latin1.json"
L1="$TMP/latin1-rec.json"
printf '\377' > "$L1"
refused_cleanly "set refuses a record that is not UTF-8" "$L1" set "$L1" K1 title --value '"x"'
for c in NaN Infinity -Infinity; do
  refused_cleanly "set refuses $c" "$S" set "$S" K1 title "--value=$c"
done

# Every write, not only set, refuses a missing, malformed or unwritable record.
one_phase="[$(phase K1 known open '[]')]"
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
write_rec "$P" "$(phase K1 known open '[]')" "$(phase K2 known open '["K1"]')"
new_phases="[$(phase K1 known open '[]'),$(phase K2a known open '["K1"]'),$(phase K2b known open '["K2a"]')]"
record set-phases "$P" --value "$new_phases"
if jq -e . "$P" >/dev/null; then pass "set-phases leaves valid JSON"; else fail "set-phases leaves valid JSON"; fi
check "set-phases replaces the phases with exactly the new ones" \
  "$(jq -c . <<<"$new_phases")" "$(jq -c '.phases' "$P")"
check "set-phases keeps umbrella and base" '"u.md" "main"' "$(jq -c '.umbrella, .base' "$P" | paste -sd' ')"
if [[ ! -e "$P.tmp" ]]; then pass "set-phases leaves no .tmp file"; else fail "set-phases leaves no .tmp file"; fi
one="$(phase K1 known open '[]')"
refuses "set-phases refuses an object" "$P" record set-phases "$P" --value "$one"
refuses "set-phases refuses a phase missing a key" "$P" record set-phases "$P" \
  --value "[$(jq -c 'del(.title)' <<<"$one")]"
refuses "set-phases refuses a repeated id" "$P" record set-phases "$P" --value "[$one,$one]"

# new-record
N="$TMP/new/e/effort.json"
good="$(printf '%s\n' "$one" "$(phase K2 known open '["K1"]')" | jq -sc '{umbrella:"u.md", base:"main", phases:.}')"
record new-record "$N" --value "$good"
check "new-record writes the record it is given" "$good" "$(jq -c . "$N" 2>/dev/null || true)"
if [[ ! -e "$N.tmp" ]]; then pass "new-record leaves no .tmp file"; else fail "new-record leaves no .tmp file"; fi
refuses "new-record refuses an existing record" "$N" record new-record "$N" --value "$good"
N2="$TMP/new/e2/effort.json"
refuses "new-record refuses a record without base" "$N2" record new-record "$N2" \
  --value "$(jq -c 'del(.base)' <<<"$good")"
refuses "new-record refuses a phase with an extra key" "$N2" record new-record "$N2" \
  --value "$(jq -c '.phases[0].head = 1' <<<"$good")"
refuses "new-record refuses a phase with a branch key" "$N2" record new-record "$N2" \
  --value "$(jq -c '.phases[0].branch = null' <<<"$good")"
refuses "new-record refuses malformed JSON" "$N2" record new-record "$N2" --value '{'

if ((failures > 0)); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "All record command tests passed"
