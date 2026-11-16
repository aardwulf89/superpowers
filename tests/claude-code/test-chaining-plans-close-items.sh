#!/usr/bin/env bash
# Integration Test: chaining-plans Close (partner items, and a stale learned line)
#
# Effort A has three phases. A1 is done and closed; its `learned` tells later
# phases that notes are added through `addNote(text)`. A2 is merged into main
# and its branch deleted, but it was never closed. Its commits rename
# `addNote` to `add`, and one commit message leaves an "Unfinished" line:
# whether an empty note should be refused is the owner's call. The Build
# stage copied that line into A2's `closing.unfinished` without the prefix.
# A3, "Search notes by word", is `needs-partner` with one question that has
# nothing to do with empty notes.
#
# A fresh session is asked to continue the effort. Resume's settle step must
# close A2: sort the executor's line into a `Partner item: ` line with an
# interim default, keep it out of A3's `partner_questions` (it does not
# block), revise A1's stale `addNote` line, and report the open item with
# the "Open for you:" line. Then Resume picks A3, whose intent round asks its
# own question. No plan, no new branch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PLUGIN_DIR="$REPO_ROOT"
EFFORT=A
UMBRELLA=docs/superpowers/specs/A.md
REC=.superpowers/chain/$EFFORT/effort.json
PROMPT="Use the superpowers:chaining-plans skill to continue the effort."

echo "========================================"
echo " Integration Test: chaining-plans Close (partner items)"
echo "========================================"
echo ""

TEST_PROJECT=$(create_test_project)
echo "Test project: $TEST_PROJECT"
# shellcheck disable=SC2064 # the path is fixed now, on purpose
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

mkdir -p docs/superpowers/specs docs/superpowers/plans
cat > "$UMBRELLA" <<'EOF'
# A: Notes CLI design

Status: approved by the human partner, 2026-01-01.

## Intent

A small command-line tool for keeping plain-text notes on one machine,
and for finding a note again by a word in it.

## Goals

- Adding a note takes one command and no editor.
- A note can be found by a word in it.

## Non-goals

- No new runtime dependencies.
- Sync between machines.

## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** none

### A1: Storage

- **Purpose:** Keep notes in memory, with a function that adds a note.
- **Limits:** No search; A3 builds it.
- **Answers:** none asked
- **Depends on:** none
- **Waits on:** none

### A2: A short API

- **Purpose:** Give the notes API short names: the add function is `add`.
- **Limits:** No new behavior.
- **Answers:** none asked
- **Depends on:** A1
- **Waits on:** none

### A3: Search notes by word

- **Purpose:** `search(word)` returns every note that holds the word.
- **Limits:** Search only; no ranking.
- **Answers:** none asked
- **Depends on:** A2
- **Waits on:** none
EOF

git add .
git commit -q -m "Initial commit: notes design"

# A1's build, merged into main and its branch deleted.
git checkout -q -b A1
cat > notes.js <<'EOF'
const notes = [];
function addNote(text) { notes.push(text); return notes.length; }
module.exports = { addNote };
EOF
cat > notes.test.js <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { addNote } = require('./notes');
test('addNote returns the count', () => { assert.strictEqual(addNote('a'), 1); });
EOF
git add .
git commit -q -m "feat(A1): keep notes in memory with addNote(text)"
git checkout -q main
git merge -q --no-ff A1 -m "Merge branch 'A1'"
git branch -q -d A1

# A2's build, merged into main and its branch deleted, never closed.
git checkout -q -b A2
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
git add .
git commit -q -m "refactor(A2): rename addNote to add"
cat >> notes.test.js <<'EOF'
test('an empty note is stored', () => { assert.strictEqual(add(''), 2); });
EOF
git add .
git commit -q -m "test(A2): an empty note is stored

Unfinished: whether an empty note should be refused is the owner's call; today it is stored."
git checkout -q main
git merge -q --no-ff A2 -m "Merge branch 'A2'"
git branch -q -d A2

mkdir -p "$(dirname "$REC")"
jq -n --arg spec "$UMBRELLA" '{
  umbrella: $spec,
  base: "main",
  marked: true,
  phases: [
    {
      id: "A1", title: "Storage", status: "known",
      depends_on: [], waits_on: [], partner_questions: [],
      spec: $spec, plan: null, branch: "A1",
      closing: {
        rulings: [],
        unfinished: [],
        learned: ["For A2 and A3: notes are added through addNote(text) in notes.js"],
        replan: []
      }
    },
    {
      id: "A2", title: "A short API", status: "known",
      depends_on: ["A1"], waits_on: [], partner_questions: [],
      spec: $spec, plan: null, branch: "A2",
      closing: {
        rulings: [],
        unfinished: ["Task A2.1: whether an empty note should be refused is the owner'"'"'s call; today it is stored."],
        learned: null,
        replan: null
      }
    },
    {
      id: "A3", title: "Search notes by word", status: "needs-partner",
      depends_on: ["A2"], waits_on: [],
      partner_questions: ["Should search match whole words only?"],
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
rm -f "$OUTPUT_FILE"

# The session transcript. claude names the project directory after the real
# cwd with every non-alphanumeric character as `-`.
TEST_PROJECT_REAL=$(cd "$TEST_PROJECT" && pwd -P)
SESSION_DIR="$HOME/.claude/projects/$(echo "$TEST_PROJECT_REAL" | sed 's|[^a-zA-Z0-9]|-|g')"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)

FAILED=0
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

ITEM_LINE='.phases[1].closing.unfinished // [] | map(select(startswith("Partner item: ") and test("empty"; "i")))'
SUFFIX='\\[(settled: [^\\]]+|dropped|carried|adopted by [^\\]]+)\\]$'

jq_check "A2's closing.replan is set (A2 is closed)" '.phases[1].closing.replan != null'
jq_check "A2's unfinished has an open 'Partner item: ' line on empty notes" \
    "$ITEM_LINE | length > 0 and all(test(\"$SUFFIX\") | not)"
jq_check "The partner item states an interim default" \
    "$ITEM_LINE | any(test(\"[Dd]efault\"))"
jq_check "A3 keeps only its own question (the item does not block)" \
    '.phases[2].partner_questions | length == 1 and (any(test("empty"; "i")) | not)'
jq_check "No line of A1's learned names addNote as current" \
    '.phases[0].closing.learned // [] | all((test("addNote") | not) or test("\\badd\\("))'

# The close's report is not the run's final message, which is A3's intent
# round. The digit keeps the template in the loaded close.md from matching.
if [ -n "$SESSION_FILE" ] && grep -qE "Open for you: [0-9]+ new item" "$SESSION_FILE"; then
    pass "The close reports the open items"
else
    fail "No 'Open for you: <n> new items' line in the transcript"
fi

plans=$(find "$TEST_PROJECT/docs/superpowers/plans" -type f 2>/dev/null || true)
if [ -n "$plans" ]; then
    fail "Plan files written: $plans"
else
    pass "No plan written (Resume stops at A3's intent round)"
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
