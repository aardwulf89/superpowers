#!/usr/bin/env bash
# Integration Test: chaining-plans Create (the intent sitting)
#
# Gives a fresh session an approved three-part spec and asks it to create an
# effort. A headless run gets one turn, so the sitting stays unanswered. The
# skill must show the phases in order with what each waits on, ask, and
# write nothing yet: no record, no plan, no commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PLUGIN_DIR="$REPO_ROOT"

echo "========================================"
echo " Integration Test: chaining-plans Create"
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

mkdir -p docs/superpowers/specs
cat > docs/superpowers/specs/A.md <<'EOF'
# A: Notes CLI design

Status: approved by the human partner, 2026-01-01.

## Intent

A small command-line tool for keeping plain-text notes on one machine:
`notes add`, `notes find`, `notes export`.

## Goals

- Adding a note takes one command and no editor.
- Finding a note is fast enough to feel instant on a few thousand notes.
- Notes can leave the tool in a portable form.

## Non-goals

- Sync between machines.
- A graphical interface.

## The order of work

The work comes in three parts, in this order.

1. **Storage.** How notes are kept on disk: one file per note or one
   file for all, and the `notes add` command. Everything else reads
   notes through this part.
2. **Search.** The `notes find` command over the stored notes. Building
   it will show how large real notes get, since search has to read them
   all.
3. **Export.** The `notes export` command. Its format depends on what the
   search part learns about note size: small notes suit one combined
   file, large ones suit an archive of separate files. Decide the format
   once search has measured real notes.

Not yet decided: whether search covers note bodies or only titles, and
who export is for (the owner's backups, or sharing notes with other
people).
EOF

git add .
git commit -q -m "Initial commit: notes design"
commits_before=$(git rev-list --count main)

PROMPT="Use the superpowers:chaining-plans skill to create an effort from docs/superpowers/specs/A.md."

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

echo ""
echo "=== Verification ==="

# A loaded skill's text starts with its base directory; a failed Skill call
# ("Unknown skill") leaves no such line.
if [ -n "$SESSION_FILE" ] && grep -qF "Base directory for this skill: $PLUGIN_DIR/skills/chaining-plans" "$SESSION_FILE"; then
    echo "  [PASS] chaining-plans skill loaded from the plugin dir"
else
    echo "  [FAIL] chaining-plans skill not loaded (transcript: ${SESSION_FILE:-none})"
    FAILED=$((FAILED + 1))
fi

check assert_contains "$output" "storage" "Names the storage phase"
check assert_contains "$output" "search" "Names the search phase"
check assert_contains "$output" "export" "Names the export phase"
check assert_contains "$output" "\bA[1-9]\b" "Gives the phases A<n> ids"
check assert_order "$output" "storage" "export" "Storage comes before export"
check assert_contains "$output" "wait\|depends\|after" "Says what export waits on"
check assert_contains "$output" "?" "Asks the human partner"

if [ -e "$TEST_PROJECT/.superpowers/chain" ]; then
    echo "  [FAIL] A record was written before the sitting was answered:"
    find "$TEST_PROJECT/.superpowers/chain" | sed 's/^/    /'
    FAILED=$((FAILED + 1))
else
    echo "  [PASS] No record yet (no .superpowers/chain)"
fi

dirty=$(git -C "$TEST_PROJECT" status --porcelain)
if [ -z "$dirty" ]; then
    echo "  [PASS] Working tree clean"
else
    echo "  [FAIL] Working tree changed:"
    echo "$dirty" | sed 's/^/    /'
    FAILED=$((FAILED + 1))
fi

plans=$(find "$TEST_PROJECT/docs/superpowers/plans" -type f 2>/dev/null || true)
if [ -n "$plans" ]; then
    echo "  [FAIL] Plan files written: $plans"
    FAILED=$((FAILED + 1))
else
    echo "  [PASS] No plan written"
fi

commits_after=$(git -C "$TEST_PROJECT" rev-list --count main)
if [ "$commits_after" -eq "$commits_before" ]; then
    echo "  [PASS] No commit on main ($commits_after)"
else
    echo "  [FAIL] main moved from $commits_before to $commits_after commits"
    FAILED=$((FAILED + 1))
fi

if bash "$REPO_ROOT/tests/skill-size/test-skill-size.sh"; then
    echo "  [PASS] Skill size"
else
    echo "  [FAIL] Skill size"
    FAILED=$((FAILED + 1))
fi

if bash "$REPO_ROOT/tests/skill-layout/test-no-dev-files-in-skills.sh"; then
    echo "  [PASS] Skill layout"
else
    echo "  [FAIL] Skill layout"
    FAILED=$((FAILED + 1))
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "STATUS: PASSED"
    exit 0
else
    echo "STATUS: FAILED ($FAILED checks)"
    exit 1
fi
