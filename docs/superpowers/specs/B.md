# B: chaining-plans under Claude Code's native worktrees

## Intent

A chained effort must run end to end through Claude Code's own worktree
tool (`EnterWorktree`), as `using-git-worktrees` Step 1a directs. A session
on effort C phase C1 (bug report `~/tmp/2026-11-13-chaining-plans-gaps.md`)
only finished by stepping off the skills' rails at four places. Each phase
should run as written, with no hand-made workarounds.

## What breaks today

Root cause: chaining-plans was written for a plain `git worktree add`
worktree that the session can step in and out of. The native tool differs:

- It branches from `origin/<default branch>`. **Resolved** by the user
  setting `worktree.baseRef: "head"` (done; no skill change).
- It isolates the session. Bash commands that are compound and name git,
  or that the guard cannot parse, are refused. So are commands whose
  working directory is the main checkout, and `git -C <main checkout>`.
  Reproduced: `chain-dir`, `phase-state` and `set` from `record.md` were
  all refused. A script run by its path ran, and wrote the record.
- It names the branch `worktree-<name>`. The caller cannot choose the name.
- After the session leaves, nothing removes the worktree. `git branch -d`
  then fails, because the branch is still checked out there (tested).
- Separately, `close.md` and `resume.md` have the agent build the
  `closing` JSON by hand with jq. In the reported session that hung on
  stdin.

## Approaches

- **Plain worktree plus `cd`, bypassing the native tool.** Rejected by the
  user: everything should use `EnterWorktree`.
- **Native tool, with record commands as scripts run by path (chosen).**
  The guard accepts a script run by its path.
- **Native tool, leaving the worktree around every record write.**
  Rejected: one write (`branch`) falls in the middle of the build.

## Design

1. **Leave the worktree before the merge.** `finishing-a-development-branch`
   runs Steps 1 to 4 inside the worktree: its Step 2 must detect the
   worktree from inside it, so its capture block becomes plain
   `git rev-parse` commands, one per Bash call, whose printed paths the
   agent compares. In Step 5, option 1 and a confirmed
   discard first leave a session-isolated worktree (`ExitWorktree` with
   `keep`), then change to the main checkout. Under isolation that `cd`
   and merge are refused, for any user of `finishing`, not only chains.
2. **The branch is what the tool creates.** The record stores that name
   (`worktree-C1`). The rule "branch name = phase id" goes from
   `SKILL.md`, and Resume step 2's leftover-branch check matches the tool's
   name too.
3. **Cleanup after a merge or a discard.** `finishing` Step 6, and Resume's
   PR cleanup, remove a worktree under `.claude/worktrees/` that this
   session used, once its branch is merged or, in `finishing`, its discard
   is confirmed: `git worktree remove <path>`, never
   `--force`. A refused removal follows Step 6's existing refusal menu.
4. **The record commands become one Python script,**
   `skills/chaining-plans/scripts/record`, run by its absolute path:
   `python3 <path> <subcommand> <args>`. It uses only the standard library,
   so `jq` is no longer needed. Subcommands: `chain-dir`, `open-efforts`,
   `phase-state`, `pick`, `new-record`, `set`, `set-phases`, `get`,
   `set-closing-key`.
   - Inputs are arguments. JSON values come from a file path, since the
     Write tool cannot write into the main checkout from a worktree. Value
     files go in a temp directory.
   - Each command keeps the checks and behavior of today's block: on
     failure it says why on stderr, exits non-zero, and changes nothing.
     Writes go through a temp file and an atomic rename.
   - `get` covers the reads that the references now do with inline jq:
     a phase's field, and the `waits_on` questions a phase must answer.
   - `set-closing-key` takes `rec`, a phase id, a key (`rulings`,
     `unfinished`, `learned`, `replan`), a value file, and a mode
     (`replace`, or `append` for list keys). It reads `closing` fresh,
     starts a null one as
     `{"rulings": [], "unfinished": [], "learned": null, "replan": null}`,
     and refuses to set `replan` back to null.
   - The script runs git read-only (state checks) and writes only the
     record.
5. **Docs.** `record.md` documents the subcommands in place of the shell
   blocks, and keeps the shape, fields, states and the `set-phases` rules.
   `create.md`, `resume.md`, `close.md` and `SKILL.md` name the subcommands.
   The design doc `2026-11-12-chaining-plans-design.md` gets a note on the
   native tool.
6. **Tests.** `tests/chaining-plans/test-record-commands.sh` calls the
   script instead of extracting blocks, and keeps every current case. New
   cases cover `get` and `set-closing-key`. `tests/reference-ids`
   assertions on `record.md` still hold.
7. **A leftover from a session that ended before recording `branch`.**
   Checked live: `EnterWorktree` given an existing name resumes that
   worktree as-is (its commits, uncommitted files and ledger), and when
   only the branch `worktree-<name>` is left, it silently resets the
   branch to the current HEAD (the commits survive only in the reflog).
   So Resume's Build, for a worktree build of a phase whose `branch` is
   null, looks for `worktree-<phase id>` first. It goes on only when the
   branch has no commits beyond `base` and its worktree, if any, is
   clean. Otherwise it reports and stops. The build-in-place rule already
   does the same for a leftover `<phase id>` branch.

## Non-goals

- No change to `using-git-worktrees`.
- No change to the record's shape or its phase states.

## Left to the builder

The script's internal layout, the exact argument spelling, and the test
harness details.
