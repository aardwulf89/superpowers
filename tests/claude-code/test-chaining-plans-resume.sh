#!/usr/bin/env bash
# Integration Test: chaining-plans Resume
#
# Four fresh sessions, each asked to continue an effort:
#   A. The last phase is closed but its git ops were missed, and origin
#      has a commit main lacks. Resume pulls base, merges the phase, pushes
#      base, removes the branch and the worktree, and reports the merge and
#      that the effort is done.
#   B. As A, but `origin` is unreachable (its URL is a missing path), so
#      the push check fails. Resume stops before merging, with the branch
#      and the worktree still in place.
#   C. The pick is a phase still marked `waiting`. Resume reports the
#      inconsistency and starts nothing.
#   D. As A, but the branch has an open PR (a `gh` stub on PATH stands in
#      for GitHub). Resume merges the PR with a method flag, pulls base, and
#      removes the local branch, the worktree and the remote branch.
# The four run in parallel; each is its own `claude -p` session.
#
# Isolation: each session loads the human partner's ~/.claude/CLAUDE.md,
# which may define "git ops" (for example "the relevant subset of merge +
# push + delete branch"). Every fixture has an origin configured, so that
# definition and the one in SKILL.md call for the same steps here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PLUGIN_DIR="$REPO_ROOT"
EFFORT=2026-01-01-notes-design
UMBRELLA=docs/superpowers/specs/$EFFORT.md
PLAN=docs/superpowers/plans/2026-01-01-notes-p1-storage.md
PROMPT="Use the superpowers:chaining-plans skill to continue the effort."

echo "========================================"
echo " Integration Test: chaining-plans Resume"
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

# A project with a passing `node --test` suite (finishing runs it) and an
# umbrella spec with a Phases section, on main. With "plan", p1's plan too.
make_project() {
    local dir=$1 with_plan=${2:-}
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
# Notes CLI: design

Status: approved by the human partner, 2026-01-01.

## Intent

A small command-line tool for keeping plain-text notes on one machine.

## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** none

### p1-storage: Storage

- **Purpose:** Keep notes in memory, with `add(text)` and `find(text)`.
- **Limits:** No storage on disk, no export.
- **Answers:** none asked
- **Depends on:** none
- **Waits on:** none
EOF

    [ "$with_plan" = plan ] && cat > "$PLAN" <<EOF
# Notes Storage Implementation Plan

**Goal:** Add \`find(text)\` next to \`add(text)\`.

**Spec:** \`$UMBRELLA\`

### Task 1: find

- [ ] Add \`find\` and its test.
EOF

    git add .
    git commit -q -m "Initial commit: notes design"
}

# p1's build: one commit on branch p1, in .worktrees/p1, workspace deleted.
make_p1_branch() {
    git worktree add -q .worktrees/p1 -b p1
    cat >> .worktrees/p1/notes.js <<'EOF'
module.exports.find = (text) => notes.filter((n) => n.includes(text));
EOF
    cat >> .worktrees/p1/notes.test.js <<'EOF'
test('find returns matches', () => {
  const { find } = require('./notes');
  add('hello');
  assert.deepStrictEqual(find('hell'), ['hello']);
});
EOF
    git -C .worktrees/p1 commit -q -am "feat: find"
}

# Writes the record with the given phase as its only phase.
write_record() {
    local phase=$1
    mkdir -p ".superpowers/chain/$EFFORT"
    jq -n --arg umbrella "$UMBRELLA" --argjson phase "$phase" \
        '{umbrella: $umbrella, base: "main", phases: [$phase]}' \
        > ".superpowers/chain/$EFFORT/effort.json"
}

CLOSED_P1=$(jq -n --arg spec "$UMBRELLA" --arg plan "$PLAN" '{
  id: "p1-storage", title: "Storage", status: "known",
  depends_on: [], waits_on: [], partner_questions: [],
  spec: $spec, plan: $plan, branch: "p1",
  closing: {
    rulings: ["Kept notes in an array: the plan named no store"],
    unfinished: ["none: the plan had one task and it is done"],
    learned: ["Notes are short; an array is enough"],
    replan: []
  }
}')

# --- Fixture A: missed git ops on the last phase, with an origin ---
A="$TEST_ROOT/a"
make_project "$A" plan
git init -q --bare -b main "$TEST_ROOT/a-origin.git"
git remote add origin "$TEST_ROOT/a-origin.git"
git push -q -u origin main
# origin moves ahead of the local main, from another clone.
git clone -q "$TEST_ROOT/a-origin.git" "$TEST_ROOT/a-other"
git -C "$TEST_ROOT/a-other" -c user.email=o@test.com -c user.name=Other \
    commit -q --allow-empty -m "chore: a commit made elsewhere"
git -C "$TEST_ROOT/a-other" push -q origin main
A_REMOTE=$(git -C "$TEST_ROOT/a-other" rev-parse HEAD)
make_p1_branch
write_record "$CLOSED_P1"
A_TIP=$(git rev-parse p1)

# --- Fixture B: as A, with an unreachable origin ---
B="$TEST_ROOT/b"
make_project "$B" plan
git remote add origin "$TEST_ROOT/missing-origin.git"
make_p1_branch
write_record "$CLOSED_P1"
B_MAIN=$(git rev-parse main)

# --- Fixture C: the pick is still `waiting` ---
C="$TEST_ROOT/c"
make_project "$C"
write_record "$(jq -n '{
  id: "p1-storage", title: "Storage", status: "waiting",
  depends_on: [], waits_on: [], partner_questions: [],
  spec: null, plan: null, branch: null, closing: null
}')"
C_DOCS_BEFORE=$(cd "$C" && find docs/superpowers/specs docs/superpowers/plans -type f | sort)

# --- Fixture D: as A, with an open PR for p1 ---
D="$TEST_ROOT/d"
make_project "$D" plan
git init -q --bare -b main "$TEST_ROOT/d-origin.git"
git remote add origin "$TEST_ROOT/d-origin.git"
git push -q -u origin main
make_p1_branch
git push -q origin p1
write_record "$CLOSED_P1"
D_TIP=$(git rev-parse p1)
D_BIN="$TEST_ROOT/d-bin"
D_GH_LOG="$TEST_ROOT/d-gh.log"
mkdir -p "$D_BIN"
echo OPEN > "$TEST_ROOT/d-pr-state"
: > "$D_GH_LOG"
# A stand-in for gh: PR #1, from p1 into main. `gh pr merge` merges it on
# origin with a merge commit, as GitHub would; then the PR reads MERGED.
cat > "$D_BIN/gh" <<EOF
#!/usr/bin/env bash
state_file="$TEST_ROOT/d-pr-state"
origin="$TEST_ROOT/d-origin.git"
echo "gh \$*" >> "$D_GH_LOG"
st=\$(cat "\$state_file")
q=""
args=("\$@")
for ((i = 0; i < \${#args[@]}; i++)); do
    case "\${args[i]}" in -q|--jq) q="\${args[i+1]}" ;; esac
done
out() { if [ -n "\$q" ]; then jq -r "\$q" <<<"\$1"; else echo "\$1"; fi; }
pr='{"number":1,"state":"'"\$st"'","headRefName":"p1","baseRefName":"main","title":"p1","url":"https://example.invalid/pull/1","mergeable":"MERGEABLE"}'
case "\$1 \$2" in
    "pr view") out "\$pr" ;;
    "pr list"|"pr status") if [ "\$st" = OPEN ]; then out "[\$pr]"; else out "[]"; fi ;;
    "repo view") out '{"nameWithOwner":"owner/notes","mergeCommitAllowed":true,"squashMergeAllowed":true,"rebaseMergeAllowed":true,"deleteBranchOnMerge":false}' ;;
    "auth status") echo "Logged in to github.com as owner" ;;
    "pr merge")
        [ "\$st" = OPEN ] || { echo "Pull request #1 is not open" >&2; exit 1; }
        tmp=\$(mktemp -d)
        git clone -q "\$origin" "\$tmp/c" &&
            git -C "\$tmp/c" -c user.email=gh@example.invalid -c user.name=GitHub \
                merge -q --no-ff origin/p1 -m "Merge pull request #1 from owner/p1" &&
            git -C "\$tmp/c" push -q origin main || exit 1
        case " \$* " in *" -d "*|*" --delete-branch "*) git -C "\$tmp/c" push -q origin --delete p1 ;; esac
        rm -rf "\$tmp"
        echo MERGED > "\$state_file"
        echo "Merged pull request #1 (p1)" ;;
    *) echo "gh stub: unsupported: \$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$D_BIN/gh"

cd "$TEST_ROOT"

# Run in the background only: it replaces its subshell with timeout, so $!
# is timeout's pid and killing it ends the claude session too. An optional
# second argument is put first on PATH.
run_fixture() {
    local dir=$1 bin=${2:-}
    cd "$dir" || exit 1
    PATH="${bin:+$bin:}$PATH" exec timeout 840 claude -p "$PROMPT" --plugin-dir "$PLUGIN_DIR" \
        --permission-mode bypassPermissions < /dev/null > "$dir.out" 2>&1
}

echo "Running Claude on fixtures A, B, C and D in parallel (plugin-dir: $PLUGIN_DIR)..."
run_fixture "$A" & pid_a=$!
run_fixture "$B" & pid_b=$!
run_fixture "$C" & pid_c=$!
run_fixture "$D" "$D_BIN" & pid_d=$!
pids="$pid_a $pid_b $pid_c $pid_d"
status_a=0; wait "$pid_a" || status_a=$?
status_b=0; wait "$pid_b" || status_b=$?
status_c=0; wait "$pid_c" || status_c=$?
status_d=0; wait "$pid_d" || status_d=$?
pids=""

FAILED=0
check() { "$@" || FAILED=$((FAILED + 1)); }
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }

# Prints a fixture's output, checks that the session ran and loaded the
# skill, and sets SESSION_FILE to its transcript. A loaded skill's text starts with its base directory; a failed
# Skill call ("Unknown skill") leaves no such line. claude names the project
# directory after the real cwd with every non-alphanumeric character as `-`.
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
    local real session_dir
    real=$(cd "$dir" && pwd -P)
    session_dir="$HOME/.claude/projects/$(echo "$real" | sed 's|[^a-zA-Z0-9]|-|g')"
    SESSION_FILE=$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1 || true)
    if [ -n "$SESSION_FILE" ] && grep -qF "Base directory for this skill: $PLUGIN_DIR/skills/chaining-plans" "$SESSION_FILE"; then
        pass "Fixture $name: chaining-plans skill loaded from the plugin dir"
    else
        fail "Fixture $name: chaining-plans skill not loaded (transcript: ${SESSION_FILE:-none})"
    fi
}

# --- A ---
show_and_check_run A "$A" "$status_a"
out_a=$(cat "$A.out")
if git -C "$A" merge-base --is-ancestor "$A_TIP" main 2>/dev/null; then
    pass "A: p1's tip is merged into main"
else
    fail "A: p1's tip is not an ancestor of main"
fi
if git -C "$A" rev-parse -q --verify refs/heads/p1 >/dev/null; then
    fail "A: branch p1 still exists"
else
    pass "A: branch p1 deleted"
fi
if [ -e "$A/.worktrees/p1" ]; then
    fail "A: .worktrees/p1 still exists"
else
    pass "A: .worktrees/p1 removed"
fi
if git -C "$A" merge-base --is-ancestor "$A_REMOTE" main 2>/dev/null; then
    pass "A: origin's newer commit is on main (base pulled before the merge)"
else
    fail "A: origin's newer commit is not on main"
fi
if git -C "$A" fetch -q origin 2>/dev/null &&
    [ "$(git -C "$A" rev-parse main)" = "$(git -C "$A" rev-parse origin/main)" ]; then
    pass "A: main is pushed to origin"
else
    fail "A: main and origin/main differ (or the fetch failed)"
fi
check assert_contains "$(echo "$out_a" | grep -v '^[[:space:]]*$' | head -3)" "merg" "A: reports the merge at the top"
check assert_contains "$out_a" "\bp1\b" "A: names the merged branch"
check assert_contains "$out_a" "push" "A: reports whether main was pushed"
check assert_contains "$out_a" "effort.*\(done\|complete\|finished\)\|\(done\|complete\).*effort\|all phases\|every phase" "A: reports that the effort is done"

# --- B ---
show_and_check_run B "$B" "$status_b"
out_b=$(cat "$B.out")
if git -C "$B" rev-parse -q --verify refs/heads/p1 >/dev/null; then
    pass "B: branch p1 kept"
else
    fail "B: branch p1 was deleted"
fi
if [ -d "$B/.worktrees/p1" ]; then
    pass "B: .worktrees/p1 kept"
else
    fail "B: .worktrees/p1 was removed"
fi
if [ "$(git -C "$B" rev-parse main)" = "$B_MAIN" ]; then
    pass "B: main unchanged (the push check stops before the merge)"
else
    fail "B: main moved"
fi
# The session's own Bash commands, not the skill text it read.
b_commands=$(jq -r 'select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Bash") | .input.command' \
    "${SESSION_FILE:-/dev/null}" 2>/dev/null || true)
# resume.md pulls base before the push dry run and stops at the first that
# fails, so a correct session may stop at the pull and never run the push.
if echo "$b_commands" | grep -qE 'git( -C [^ ]+)? (pull|push)'; then
    pass "B: the session tried to reach origin (pull or push)"
else
    fail "B: no git pull or push among the session's commands"
fi
check assert_contains "$out_b" "push.*\(fail\|refus\|reject\|error\)\|\(fail\|refus\|reject\).*push\|origin.*not.*\(repo\|exist\)\|unreachable" "B: reports the push failure"

# --- C ---
show_and_check_run C "$C" "$status_c"
out_c=$(cat "$C.out")
check assert_contains "$out_c" "inconsistent" "C: names the inconsistency"
C_DOCS_AFTER=$(cd "$C" && find docs/superpowers/specs docs/superpowers/plans -type f | sort)
if [ "$C_DOCS_AFTER" = "$C_DOCS_BEFORE" ]; then
    pass "C: no spec or plan written"
else
    fail "C: docs changed: $(diff <(echo "$C_DOCS_BEFORE") <(echo "$C_DOCS_AFTER") || true)"
fi
c_branches=$(git -C "$C" for-each-ref --format='%(refname:short)' refs/heads)
if [ "$c_branches" = "main" ]; then
    pass "C: no branch other than main"
else
    fail "C: branches: $(echo $c_branches)"
fi

# --- D ---
show_and_check_run D "$D" "$status_d"
out_d=$(cat "$D.out")
echo "  gh calls:"
sed 's/^/    /' "$D_GH_LOG"
if grep -qE '^gh pr merge .*(--merge|--squash|--rebase|-m|-s|-r)( |$)' "$D_GH_LOG"; then
    pass "D: gh pr merge ran, with a merge method"
else
    fail "D: no gh pr merge with --merge, --squash or --rebase"
fi
if git -C "$D" log --merges --format=%s main | grep -qF "Merge branch 'p1'"; then
    fail "D: p1 was merged locally instead of through its PR"
else
    pass "D: no local merge of p1"
fi
if git -C "$D" merge-base --is-ancestor "$D_TIP" main 2>/dev/null; then
    pass "D: main pulled the PR's merge"
else
    fail "D: p1's tip is not on main (base not pulled after the PR merge)"
fi
if git -C "$D" rev-parse -q --verify refs/heads/p1 >/dev/null; then
    fail "D: local branch p1 still exists"
else
    pass "D: local branch p1 deleted"
fi
if [ -e "$D/.worktrees/p1" ]; then
    fail "D: .worktrees/p1 still exists"
else
    pass "D: .worktrees/p1 removed"
fi
if [ -z "$(git -C "$D" ls-remote --heads origin p1 2>/dev/null)" ]; then
    pass "D: origin's p1 deleted"
else
    fail "D: origin still has p1"
fi
check assert_contains "$out_d" "PR\|pull request" "D: reports the PR merge"

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
