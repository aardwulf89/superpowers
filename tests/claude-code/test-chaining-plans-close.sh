#!/usr/bin/env bash
# Integration Test: chaining-plans Close (a missed close, with an intent conflict)
#
# Phase p1 is merged into main and its branch deleted, but it was never
# closed. Its merged commit found that PDF export needs a third-party library,
# and the umbrella's non-goals rule out new runtime dependencies. Phase p2,
# "Export to PDF", waits on that answer.
#
# A fresh session is asked to continue the effort. Resume's settle step must
# close p1: write `learned` from the merged commits, write `replan`, and, since
# the answer conflicts with the intent, ask instead of ruling: p2 gets a
# question in `partner_questions` and the status `needs-partner`. Then Resume
# picks p2, whose intent round asks the question. No plan, no new branch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PLUGIN_DIR="$REPO_ROOT"
EFFORT=2026-01-01-notes-design
UMBRELLA=docs/superpowers/specs/$EFFORT.md
REC=.superpowers/chain/$EFFORT/effort.json
PROMPT="Use the superpowers:chaining-plans skill to continue the effort."

echo "========================================"
echo " Integration Test: chaining-plans Close"
echo "========================================"
echo ""

TEST_PROJECT=$(create_test_project)
echo "Test project: $TEST_PROJECT"
trap "cleanup_test_project $TEST_PROJECT" EXIT

cd "$TEST_PROJECT"
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
# Notes CLI: design

Status: approved by the human partner, 2026-01-01.

## Intent

A small command-line tool for keeping plain-text notes on one machine,
and for exporting them to PDF to print.

## Goals

- Adding a note takes one command and no editor.
- Notes can be exported to a PDF file.

## Non-goals

- No new runtime dependencies.
- Sync between machines.

## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** none

### p1: Storage

- **Purpose:** Keep notes in memory, with `add(text)`. Find out whether a
  PDF file can be written with Node's standard library, for p2.
- **Limits:** No export; p2 builds it.
- **Answers:** none asked
- **Depends on:** none
- **Waits on:** none

### p2: Export to PDF

- **Purpose:** `notes export` writes every note to one PDF file.
- **Limits:** Export only; no import.
- **Answers:** none asked
- **Depends on:** p1
- **Waits on:** p1: Can PDF export be done with the standard library?
EOF

git add .
git commit -q -m "Initial commit: notes design"

# p1's build, merged into main and its branch deleted.
git checkout -q -b p1
cat > FINDINGS.md <<'EOF'
# Findings

Export to PDF needs a third-party PDF library; the standard library cannot write PDF.
EOF
cat >> notes.test.js <<'EOF'
test('add counts every note', () => { assert.strictEqual(add('b'), 2); });
EOF
git add .
git commit -q -m "feat: storage, and findings on PDF export"
git checkout -q main
git merge -q --no-ff p1 -m "Merge branch 'p1'"
git branch -q -d p1

mkdir -p "$(dirname "$REC")"
jq -n --arg spec "$UMBRELLA" '{
  umbrella: $spec,
  base: "main",
  phases: [
    {
      id: "p1", title: "Storage", status: "known",
      depends_on: [], waits_on: [], partner_questions: [],
      spec: $spec, plan: null, branch: "p1",
      closing: {rulings: [], unfinished: [], learned: null, replan: null}
    },
    {
      id: "p2", title: "Export to PDF", status: "waiting",
      depends_on: ["p1"],
      waits_on: [{from: "p1", question: "Can PDF export be done with the standard library?"}],
      partner_questions: [],
      spec: null, plan: null, branch: null, closing: null
    }
  ]
}' > "$REC"

OUTPUT_FILE=$(mktemp)
echo "Running Claude (plugin-dir: $PLUGIN_DIR, cwd: $TEST_PROJECT)..."
echo "================================================================================"
timeout 840 claude -p "$PROMPT" --plugin-dir "$PLUGIN_DIR" --permission-mode bypassPermissions < /dev/null 2>&1 | tee "$OUTPUT_FILE" || {
    echo ""
    echo "EXECUTION FAILED"
    rm -f "$OUTPUT_FILE"
    exit 1
}
echo "================================================================================"
output=$(cat "$OUTPUT_FILE")
rm -f "$OUTPUT_FILE"

# The session transcript, for the Skill-tool check. claude names the project
# directory after the real cwd with every non-alphanumeric character as `-`.
TEST_PROJECT_REAL=$(cd "$TEST_PROJECT" && pwd -P)
SESSION_DIR="$HOME/.claude/projects/$(echo "$TEST_PROJECT_REAL" | sed 's|[^a-zA-Z0-9]|-|g')"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)

FAILED=0
check() { "$@" || FAILED=$((FAILED + 1)); }
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }
# jq_check NAME FILTER: passes when FILTER holds on the record.
jq_check() {
    if jq -e "$2" "$TEST_PROJECT/$REC" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi
}

echo ""
echo "=== Verification ==="

# A loaded skill's text starts with its base directory; a failed Skill call
# ("Unknown skill") leaves no such line.
if [ -n "$SESSION_FILE" ] && grep -qF "Base directory for this skill: $PLUGIN_DIR/skills/chaining-plans" "$SESSION_FILE"; then
    pass "chaining-plans skill loaded from the plugin dir"
else
    fail "chaining-plans skill not loaded (transcript: ${SESSION_FILE:-none})"
fi

echo "  Record after the run:"
jq '.phases[] | {id, status, partner_questions, closing}' "$TEST_PROJECT/$REC" 2>&1 | sed 's/^/    /' ||
    echo "    (the record is not readable JSON)"

jq_check "p1's closing.learned is written" '.phases[0].closing.learned | length > 0'
jq_check "p1's closing.replan is set (p1 is closed)" '.phases[0].closing.replan != null'
p2_status=$(jq -r '.phases[1].status' "$TEST_PROJECT/$REC" 2>/dev/null || true)
if [ "$p2_status" = "needs-partner" ]; then
    pass "p2 is needs-partner"
else
    fail "p2's status is '$p2_status', not needs-partner"
fi
jq_check "p2 has a question for the human partner" '.phases[1].partner_questions | length > 0'
jq_check "p2's questions are worded as questions" '.phases[1].partner_questions | all(type == "string" and test("\\?\\s*$"))'
jq_check "p2's question names the dependency conflict" \
    '.phases[1].partner_questions | any(test("depend|librar|third.party"; "i"))'
jq_check "p1's replan records the question as an intent entry for p2" \
    '.phases[0].closing.replan | any(.intent == true and (.affects | index("p2")))'
check assert_contains "$output" "?" "Asks the human partner"
check assert_contains "$output" "depend\|librar\|third.party" "The question shown names the dependency conflict"

plans=$(find "$TEST_PROJECT/docs/superpowers/plans" -type f 2>/dev/null || true)
if [ -n "$plans" ]; then
    fail "Plan files written: $plans"
else
    pass "No plan written"
fi

branches=$(git -C "$TEST_PROJECT" for-each-ref --format='%(refname:short)' refs/heads)
if [ "$branches" = "main" ]; then
    pass "No branch other than main"
else
    fail "Branches: $(echo $branches)"
fi

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
