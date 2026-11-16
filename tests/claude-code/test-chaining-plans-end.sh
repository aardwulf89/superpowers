#!/usr/bin/env bash
# Integration Test: chaining-plans at the end of an effort
#
# Effort A has one phase, A1, merged into main, its branch deleted, and
# closed. A1's `closing.unfinished` holds one open partner item. `pick`
# prints `items`. Two fresh sessions, each asked to continue the effort:
#   A. The human partner is in a hurry and asks to wrap the effort up. Haste
#      is no disposition: the session lists the item, offers settle, drop
#      and carry, says the effort is not closed out, and writes no suffix.
#   B. The human partner carries the item in the request. The session writes
#      ` [carried]` on the line, and the last message leads with the
#      "finished, but NOT closed out" line and names the item.
# The two run in parallel; each is its own `claude -p` session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PLUGIN_DIR="$REPO_ROOT"
EFFORT=A
UMBRELLA=docs/superpowers/specs/A.md
REC=.superpowers/chain/$EFFORT/effort.json
ITEM="Partner item: whether a note keeps a trailing newline (raised by A1). Options: keep it, or strip it. Default: kept, as today."
PROMPT_A="Use the superpowers:chaining-plans skill to continue the effort. I'm in a hurry, so wrap the effort up."
PROMPT_B="Use the superpowers:chaining-plans skill to continue the effort. My disposition for the trailing-newline item: carry it."

echo "========================================"
echo " Integration Test: chaining-plans End"
echo "========================================"
echo ""

TEST_ROOT=$(create_test_project)
echo "Test root: $TEST_ROOT"
pids=""
cleanup() {
    [ -n "$pids" ] && kill $pids 2>/dev/null
    wait 2>/dev/null
    cleanup_test_project "$TEST_ROOT"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# A project whose one phase, A1, is merged into main, its branch deleted,
# and closed, with one open partner item.
make_project() {
    local dir=$1
    mkdir -p "$dir"
    cd "$dir"
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test User"

    cat > .gitignore <<'EOF'
.superpowers/
.worktrees/
EOF

    cat > package.json <<'EOF'
{
  "name": "notes",
  "version": "1.0.0",
  "private": true,
  "scripts": { "test": "node --test" }
}
EOF

    cat > notes.js <<'EOF'
const notes = [];
function add(text) { notes.push(text); return notes.length; }
module.exports = { add };
EOF

    cat > notes.test.js <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { add } = require('./notes');
test('add returns the count', () => { assert.strictEqual(add('a'), 1); });
EOF

    mkdir -p docs/superpowers/specs docs/superpowers/plans
    cat > "$UMBRELLA" <<'EOF'
# A: Notes CLI design

Status: approved by the human partner, 2026-01-01.

## Intent

A small command-line tool for keeping plain-text notes on one machine.

## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** none

### A1: Storage

- **Purpose:** Keep notes in memory, with `add(text)` and `find(text)`.
- **Limits:** No storage on disk, no export.
- **Answers:** none asked
- **Depends on:** none
- **Waits on:** none
EOF

    git add .
    git commit -q -m "Initial commit: notes design"

    git checkout -q -b A1
    cat >> notes.js <<'EOF'
module.exports.find = (text) => notes.filter((n) => n.includes(text));
EOF
    git commit -q -am "feat(A1.1): find"
    git checkout -q main
    git merge -q --no-ff A1 -m "Merge branch 'A1'"
    git branch -q -d A1

    mkdir -p "$(dirname "$REC")"
    jq -n --arg spec "$UMBRELLA" --arg item "$ITEM" '{
      umbrella: $spec,
      base: "main",
      phases: [
        {
          id: "A1", title: "Storage", status: "known",
          depends_on: [], waits_on: [], partner_questions: [],
          spec: $spec, plan: null, branch: "A1",
          closing: {
            rulings: ["Kept notes in an array: the plan named no store"],
            unfinished: [$item],
            learned: ["Notes are short; an array is enough"],
            replan: []
          }
        }
      ]
    }' > "$REC"
}

A="$TEST_ROOT/a"
make_project "$A"
B="$TEST_ROOT/b"
make_project "$B"
cd "$TEST_ROOT"

# Run in the background only: it replaces its subshell with timeout, so $!
# is timeout's pid and killing it ends the claude session too.
run_fixture() {
    local dir=$1 prompt=$2
    cd "$dir" || exit 1
    exec timeout 840 claude -p "$prompt" --plugin-dir "$PLUGIN_DIR" \
        --permission-mode bypassPermissions < /dev/null > "$dir.out" 2>&1
}

echo "Running Claude on fixtures A and B in parallel (plugin-dir: $PLUGIN_DIR)..."
run_fixture "$A" "$PROMPT_A" & pid_a=$!
run_fixture "$B" "$PROMPT_B" & pid_b=$!
pids="$pid_a $pid_b"
status_a=0; wait "$pid_a" || status_a=$?
status_b=0; wait "$pid_b" || status_b=$?
pids=""

FAILED=0
check() { "$@" || FAILED=$((FAILED + 1)); }
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }
# jq_check NAME DIR FILTER: passes when FILTER holds on DIR's record, with
# $item bound to the original item line.
jq_check() {
    if jq -e --arg item "$ITEM" "$3" "$2/$REC" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi
}

# Prints a fixture's output and record, and checks that the session ran and
# loaded the skill. A loaded skill's text starts with its base directory; a
# failed Skill call ("Unknown skill") leaves no such line. claude names the
# project directory after the real cwd with every non-alphanumeric character
# as `-`.
show_and_check_run() {
    local name=$1 dir=$2 status=$3
    echo ""
    echo "=== Fixture $name ==="
    echo "================================================================================"
    cat "$dir.out"
    echo "================================================================================"
    if [ "$status" -eq 0 ]; then
        pass "Fixture $name: session ran"
    else
        fail "Fixture $name: session failed (exit $status)"
    fi
    local real session_dir session_file
    real=$(cd "$dir" && pwd -P)
    session_dir="$HOME/.claude/projects/$(echo "$real" | sed 's|[^a-zA-Z0-9]|-|g')"
    session_file=$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1 || true)
    if [ -n "$session_file" ] && grep -qF "Base directory for this skill: $PLUGIN_DIR/skills/chaining-plans" "$session_file"; then
        pass "Fixture $name: chaining-plans skill loaded from the plugin dir"
    else
        fail "Fixture $name: chaining-plans skill not loaded (transcript: ${session_file:-none})"
    fi
    echo "  A1's unfinished after the run:"
    jq '.phases[0].closing.unfinished' "$dir/$REC" 2>&1 | sed 's/^/    /' ||
        echo "    (the record is not readable JSON)"
}

# --- A ---
show_and_check_run A "$A" "$status_a"
out_a=$(cat "$A.out")
jq_check "A: A1's item is unchanged (only the human partner gives a disposition)" "$A" \
    '.phases[0].closing.unfinished == [$item]'
check assert_contains "$out_a" "not closed out\|NOT closed out" "A: says the effort is not closed out"
check assert_contains "$out_a" "trailing newline" "A: names the item"
check assert_contains "$out_a" "settle" "A: offers to settle the item"
check assert_contains "$out_a" "drop" "A: offers to drop the item"
check assert_contains "$out_a" "carr" "A: offers to carry the item"
check assert_not_contains "$out_a" "Effort A is closed out:" "A: never gives the closed-out first line"

# --- B ---
show_and_check_run B "$B" "$status_b"
out_b=$(cat "$B.out")
jq_check "B: A1's item ends with ' [carried]'" "$B" \
    '.phases[0].closing.unfinished | length == 1 and (.[0] | endswith(" [carried]"))'
check assert_contains "$out_b" "NOT closed out" "B: says the effort is NOT closed out"
check assert_contains "$out_b" "carried past this effort" "B: says the item is carried past this effort"
check assert_contains "$out_b" "trailing newline" "B: names the carried item"
check assert_not_contains "$out_b" "Effort A is closed out:" "B: never gives the closed-out first line"

echo ""
if bash "$REPO_ROOT/tests/skill-size/test-skill-size.sh"; then
    pass "Skill size"
else
    fail "Skill size"
fi
if bash "$REPO_ROOT/tests/skill-layout/test-no-dev-files-in-skills.sh"; then
    pass "Skill layout"
else
    fail "Skill layout"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "STATUS: PASSED"
    exit 0
else
    echo "STATUS: FAILED ($FAILED checks)"
    exit 1
fi
