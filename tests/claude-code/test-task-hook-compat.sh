#!/usr/bin/env bash
# Test: every TaskCreate shape the fork's skills prescribe, against pcvelz's
# TaskCreate hooks and blocker hook (spec E § 4, § 9). Synthetic inputs, no LLM.
#
# Step tasks (`<name> (<id>)`, plain) must pass both TaskCreate hooks with
# model routing on and commitStrategy at-end, in a session where a plan skill
# has run. Work tasks with reference-style ids must be judged exactly like
# pcvelz's `Task N:` tasks. Our blocker chains must complete in order under
# pre-task-blockedby-enforce.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TIER="$REPO_ROOT/hooks/pre-taskcreate-model-tier"
COMMIT="$REPO_ROOT/hooks/pre-taskcreate-commit-strategy"
BLOCKEDBY="$REPO_ROOT/hooks/examples/pre-task-blockedby-enforce.sh"
TX="$REPO_ROOT/tests/claude-code/fixtures/plan-flow-transcript.jsonl"
WORK=$(mktemp -d)
export SUPERPOWERS_USERGATE_TRACE_LOG="$WORK/trace.log"
FAILED=0
# shellcheck disable=SC2064
trap "rm -rf '$WORK'" EXIT

echo "=== Test: our task shapes against pcvelz's hooks ==="

assert() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  [PASS] $label"
    else
        echo "  [FAIL] $label — expected exit=$expected, got exit=$actual"
        echo "         stderr: $(head -3 "$WORK/stderr" 2>/dev/null | tr '\n' ' ')"
        FAILED=$((FAILED + 1))
    fi
}

# A project with model routing and the at-end commit strategy on.
PROJ="$WORK/proj"
mkdir -p "$PROJ/docs/superpowers"
echo '{"mechanical":"haiku","standard":"sonnet","frontier":"inherit"}' > "$PROJ/docs/superpowers/model-routing.json"
echo '{"commitStrategy":"at-end"}' > "$PROJ/docs/superpowers/workflow.json"
HOME_DIR="$WORK/home"
mkdir -p "$HOME_DIR"

# taskcreate HOOK SUBJECT DESCRIPTION: run HOOK on a TaskCreate; print its exit code.
taskcreate() {
    local hook="$1" input rc
    input=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "TaskCreate",
                  "tool_input": {"subject": sys.argv[1], "description": sys.argv[2]},
                  "cwd": sys.argv[3], "transcript_path": sys.argv[4]}))
' "$2" "$3" "$PROJ" "$TX")
    env HOME="$HOME_DIR" bash "$hook" >/dev/null 2>"$WORK/stderr" <<< "$input" && rc=$? || rc=$?
    echo "$rc"
}

# --- the step titles the skills prescribe, read from the skill text ---
C="$REPO_ROOT/skills/chaining-plans"
STEP_TITLES=()
for step in 'Draft the phases' 'Find the open intent questions' 'Run one sitting' 'Write it down' 'Hand over'; do
    STEP_TITLES+=("$step (K)")
done
STEP_TITLES+=("Missed close (A2)" "Missed git ops (A2)")
for stage in 'Intent round' 'Design' 'Plan' 'Build' 'Finish' 'Close'; do
    STEP_TITLES+=("$stage (A3)")
done
STEP_TITLES+=("Build (K3a)" "Build (AA12a1)" "Missed close (K10)")

echo ""
echo "Test 1: every prescribed step title appears in the skill text"
for t in 'Draft the phases (K)' 'Find the open intent questions (K)' 'Run one sitting (K)' 'Write it down (K)' 'Hand over (K)'; do
    if grep -qF "\"$t\"" "$C/references/create.md"; then echo "  [PASS] create.md names \"$t\""
    else echo "  [FAIL] create.md does not name \"$t\""; FAILED=$((FAILED + 1)); fi
done
for t in 'Missed close (A2)' 'Missed git ops (A2)' 'Design (A3)'; do
    if grep -qF "\"$t\"" "$C/references/resume.md"; then echo "  [PASS] resume.md names \"$t\""
    else echo "  [FAIL] resume.md does not name \"$t\""; FAILED=$((FAILED + 1)); fi
done
for stage in 'Intent round' 'Design' 'Plan' 'Build' 'Finish' 'Close'; do
    if grep -qE "^\| $stage( \(|  *\|)" "$C/references/resume.md"; then echo "  [PASS] resume.md's stage table has $stage"
    else echo "  [FAIL] resume.md's stage table lacks $stage"; FAILED=$((FAILED + 1)); fi
done

echo ""
echo "Test 2: step tasks pass both TaskCreate hooks (routing on, at-end, plan flow)"
STEP_DESC='Run the stage as resume.md step 6 says.'
for t in "${STEP_TITLES[@]}"; do
    assert "tier hook allows '$t'" 0 "$(taskcreate "$TIER" "$t" "$STEP_DESC")"
    assert "commit hook allows '$t'" 0 "$(taskcreate "$COMMIT" "$t" "$STEP_DESC")"
done
# Why the name comes first: spec D's id-first form reads as a plan task.
assert "tier hook blocks spec D's id-first 'A3: Design'" 2 "$(taskcreate "$TIER" "A3: Design" "$STEP_DESC")"

echo ""
echo "Test 3: work tasks with ids are judged like pcvelz's Task N: tasks"
work_desc() { # TIER_JSON_FRAGMENT EXTRA_STEPS
    printf '**Goal:** Add retry.\n\n**Files:**\n- Modify: `src/r.py`\n\n**Acceptance Criteria:**\n- [ ] retries\n\n**Verify:** `pytest` → pass\n\n**Steps:**\n- [ ] **Step 1: Write the failing test**%s\n\n```json:metadata\n{"files": ["src/r.py"], "verifyCommand": "pytest", "acceptanceCriteria": ["retries"]%s}\n```' "$2" "$1"
}
WITH_TIER=$(work_desc ', "modelTier": "mechanical"' '')
NO_TIER=$(work_desc '' '')
PER_TASK_COMMIT=$(work_desc ', "modelTier": "mechanical"' $'\n- [ ] **Step 3: Commit**')
FINAL_COMMIT=$(work_desc ', "modelTier": "mechanical"' $'\n- [ ] **Step 1: Stage and commit**\n  - Run git commit -m "feat(K3): retry".')
for subj in "Task 4: Add retry" "K3.4: Add retry" "K3.4a: Retry wrapper" "AA12.10: Add retry"; do
    assert "tier hook allows '$subj' with a tier" 0 "$(taskcreate "$TIER" "$subj" "$WITH_TIER")"
    assert "tier hook blocks '$subj' without a tier" 2 "$(taskcreate "$TIER" "$subj" "$NO_TIER")"
    assert "commit hook allows '$subj' with no commit step" 0 "$(taskcreate "$COMMIT" "$subj" "$WITH_TIER")"
    assert "commit hook blocks '$subj' with a per-task commit step" 2 "$(taskcreate "$COMMIT" "$subj" "$PER_TASK_COMMIT")"
done
for subj in "Task 9: Commit the full implementation" "K3.9: Commit the full implementation" "K3.10: Commit the full implementation"; do
    assert "commit hook exempts '$subj'" 0 "$(taskcreate "$COMMIT" "$subj" "$FINAL_COMMIT")"
done
assert "tier hook blocks a fence-less 'K3.4: Add retry' in a plan flow" 2 \
    "$(taskcreate "$TIER" "K3.4: Add retry" 'Add retry to the client.')"

# --- blocker chains ---
# chain_ok NAME TASKS EDGES ORDER: create TASKS (subjects, in order; native ids
# 1..n), add EDGES ("task:blocker"), then move each task of ORDER to in_progress
# and completed in turn. Every in_progress must be allowed.
chain_ok() {
    local name="$1" tasks="$2" edges="$3" order="$4" tx="$WORK/chain.jsonl" t e rc ok=1
    : > "$tx"
    while IFS= read -r t; do
        python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskCreate","input":{"subject":sys.argv[1],"description":"step"}}]}}))' "$t" >> "$tx"
    done <<< "$tasks"
    for e in $edges; do
        python3 -c 'import json,sys; t,b=sys.argv[1].split(":"); print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskUpdate","input":{"taskId":t,"addBlockedBy":[b]}}]}}))' "$e" >> "$tx"
    done
    for t in $order; do
        if [[ $t == +* ]]; then # +N: completed without being started (a split's parent)
            python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskUpdate","input":{"taskId":sys.argv[1],"status":"completed"}}]}}))' "${t#+}" >> "$tx"
            continue
        fi
        rc=$(printf '{"tool_name":"TaskUpdate","tool_input":{"taskId":"%s","status":"in_progress"},"transcript_path":"%s"}' "$t" "$tx" \
            | bash "$BLOCKEDBY" 2>"$WORK/stderr" >/dev/null && echo 0 || echo $?)
        if [ "$rc" != 0 ]; then ok=0; echo "  [FAIL] $name: task $t refused in_progress"; FAILED=$((FAILED + 1)); fi
        python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskUpdate","input":{"taskId":sys.argv[1],"status":"completed"}}]}}))' "$t" >> "$tx"
    done
    [ "$ok" = 1 ] && echo "  [PASS] $name completes in order"
    return 0
}

echo ""
echo "Test 4: our blocker chains complete in order under the blocker hook"
chain_ok "Create's steps" $'Draft the phases (K)\nFind the open intent questions (K)\nRun one sitting (K)\nWrite it down (K)\nHand over (K)' \
    "2:1 3:2 4:3 5:4" "1 2 3 4 5"
chain_ok "a missed close, then the stages" $'Missed close (A2)\nMissed git ops (A2)\nDesign (A3)\nPlan (A3)\nBuild (A3)\nFinish (A3)\nClose (A3)' \
    "2:1 3:1 3:2 4:3 5:4 6:5 7:6" "1 2 3 4 5 6 7"
# A split during the build: K3.4 (id 1) splits into K3.4a (3) and K3.4b (4);
# K3.5 (2) waits on K3.4. The parts take the parent's blockers (none here),
# the parent gets every part, and is completed with the last part.
chain_ok "a split's parts, then the parent, then its dependent" $'K3.4: Add retry\nK3.5: Use retry\nK3.4a: Retry wrapper\nK3.4b: Backoff schedule' \
    "2:1 4:3 1:3 1:4" "3 4 +1 2"

echo ""
echo "Test 5: the split chain refuses the dependent before the parent completes"
tx="$WORK/split-early.jsonl"
: > "$tx"
for s in "K3.4: Add retry" "K3.5: Use retry" "K3.4a: Retry wrapper"; do
    python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskCreate","input":{"subject":sys.argv[1],"description":"x"}}]}}))' "$s" >> "$tx"
done
python3 -c 'import json; [print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"TaskUpdate","input":{"taskId":t,"addBlockedBy":[b]}}]}})) for t,b in (("2","1"),("1","3"))]' >> "$tx"
rc=$(printf '{"tool_name":"TaskUpdate","tool_input":{"taskId":"2","status":"in_progress"},"transcript_path":"%s"}' "$tx" \
    | bash "$BLOCKEDBY" 2>"$WORK/stderr" >/dev/null && echo 0 || echo $?)
assert "K3.5 cannot start while K3.4 is open" 2 "$rc"

echo ""
echo "=== Summary: $FAILED failure(s) ==="
exit "$FAILED"
