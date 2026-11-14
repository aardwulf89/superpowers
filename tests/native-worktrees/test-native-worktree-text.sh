#!/usr/bin/env bash
# Pins the wording that lets chaining-plans and finishing run inside a
# worktree the harness confines the session to (Claude Code's EnterWorktree):
# leave it before work in the main checkout, record the branch name the tool
# gives, and clean the worktree up after the merge.
#
# Usage: tests/native-worktrees/test-native-worktree-text.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

failures=0
checks=0

# has FILE STRING: FILE (relative to the repo root) contains STRING.
has() {
  checks=$((checks + 1))
  if ! grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 lacks: $2" >&2
    failures=$((failures + 1))
  fi
}

# lacks FILE STRING: FILE does not contain STRING.
lacks() {
  checks=$((checks + 1))
  if grep -qF -- "$2" "$REPO_ROOT/$1"; then
    echo "[FAIL] $1 still has: $2" >&2
    failures=$((failures + 1))
  fi
}

# --- chaining-plans ---
C=skills/chaining-plans
lacks $C/SKILL.md 'the branch name,'
lacks $C/SKILL.md 'Each phase gets its own branch, named by its phase'
has $C/SKILL.md 'worktree-<phase id>'
for s in 'EnterWorktree' 'ExitWorktree' '.claude/worktrees/' 'git merge-base --is-ancestor' 'worktree-<phase id>'; do
  has $C/references/resume.md "$s"
done
has $C/references/close.md 'ExitWorktree'
# Inside a confined worktree a "$b" needs an assignment in the same call,
# which the guard may refuse: the commands name the branch literally.
# A worktree or branch left by a session that ended before recording `branch`:
# EnterWorktree resumes the worktree as-is, and resets a branch that has none.
has $C/references/resume.md 'git rev-list --count <base>..worktree-<phase id>'
has $C/references/resume.md 'resumes it as-is'
has $C/references/resume.md 'resets the branch'
lacks $C/references/resume.md "(Claude Code's \`EnterWorktree\`) for a phase whose"
lacks $C/references/resume.md '"$b"'
lacks $C/references/resume.md '"$base"'

# --- finishing-a-development-branch ---
F=skills/finishing-a-development-branch/SKILL.md

# in_section FILE HEADING TEXT: the line number of TEXT's first line in the
# section that starts at the line HEADING, up to the next heading. Lines in
# code fences are never headings (a bash comment starts with # too).
in_section() {
  awk -v h="$2" -v t="$3" '
    $0 == h { s = 1; next }
    /^```/ { fence = !fence }
    s && !fence && /^#/ { exit }
    s && index($0, t) { print NR; exit }
  ' "$REPO_ROOT/$1"
}
# before FILE HEADING FIRST SECOND: in that section, FIRST appears before SECOND.
before() {
  checks=$((checks + 1))
  local a b
  a=$(in_section "$1" "$2" "$3"); b=$(in_section "$1" "$2" "$4")
  if [[ -z "$a" || -z "$b" || "$a" -ge "$b" ]]; then
    echo "[FAIL] $1 '$2': '$3' (line ${a:-none}) is not before '$4' (line ${b:-none})" >&2
    failures=$((failures + 1))
  fi
}
# within FILE HEADING TEXT: the section has TEXT.
within() {
  checks=$((checks + 1))
  if [[ -z "$(in_section "$1" "$2" "$3")" ]]; then
    echo "[FAIL] $1 '$2' lacks: $3" >&2
    failures=$((failures + 1))
  fi
}

has $F 'ExitWorktree'
before $F '### Option 1: Merge Locally' 'ExitWorktree' 'cd "$MAIN_ROOT"'
before $F '### If your human partner asks to discard the work' 'Leave a confined worktree first' 'cd "$MAIN_ROOT"'
within $F '## Step 6: Cleanup Workspace' '.claude/worktrees/'
has $F 'or the `.claude/worktrees/` one this session entered and left'
within $F '## Step 2: Detect Environment' 'git rev-parse --path-format=absolute --git-common-dir'
lacks $F 'GIT_COMMON=$(cd'
# Step 2 notes the paths; no Bash call sets $WORKTREE_PATH any more.
lacks $F '"$WORKTREE_PATH"'

if ((failures > 0)); then
  echo "$failures of $checks checks failed" >&2
  exit 1
fi
echo "PASS: all $checks native-worktree wording checks"
