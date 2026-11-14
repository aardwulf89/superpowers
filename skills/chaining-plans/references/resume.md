# Resume: the entry prompt

Every session of an effort after Create starts here. Resume settles what
the last session left, picks the next phase, and runs that one phase
straight through to its merge menu and its close. One phase per session.

Every command named here is a subcommand of the record script. Run it as
`references/record.md` § Commands says: one plain command per Bash call.

## 1. Find the record

- **An effort id was given** (as the argument, or in the request): the
  record is `<chain dir>/<id>/effort.json`. Run `record.py chain-dir` to
  find the chain dir. If the file is missing, say so and stop.
- **No id:** run `record.py open-efforts`.
  - Nothing printed: say there is no open effort, and that an effort
    starts with Create. Stop.
  - One path: use it.
  - Several: list them by effort id, ask your human partner which one,
    and end your turn. Do not pick one for them.

The effort id is the name of the record's directory. Every later command
takes the path to `effort.json` as its `REC` argument.

## 2. Check git

- **Work in the main checkout:** the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. If the session
  started in a worktree, `cd` there. A session the harness confines to a
  worktree (Claude Code, after `EnterWorktree`) cannot `cd` out: leave it
  with `ExitWorktree`, action `keep`, instead.
- **A clean tree:** `git status --porcelain` prints nothing. If it prints
  anything, report the files and stop. They are your human partner's
  work in progress.
- **On `base`:** the main checkout has the record's `base` checked out,
  unless it has a phase's own branch checked out: the `branch` of a
  phase built in place, or a branch named `<phase id>` or
  `worktree-<phase id>` (Claude Code's `EnterWorktree`) for a phase whose
  `branch` is still null (a session ended before recording it; the Build
  stage reuses it). Anything else: report it and stop.

## 3. Settle every phase under way

Do this before the pick: `pick` reports a phase that is under way as
`blocked:`.

For each phase, in array order, run `record.py phase-state` and act on what it
prints:

| State | What happened | Action |
|---|---|---|
| `cut-off` | The build was cut off; its SDD workspace exists | This phase is this session's phase. Go to the Build stage (step 5): enter the branch's worktree (`git worktree list`; in Claude Code, `EnterWorktree` with its `path`) and re-invoke the executor there. It resumes from its own ledger. Run the stages after it, and do not pick |
| `finished-unclosed` | Finished; not closed, not merged | Close it, then do its missed git ops |
| `closed-unmerged` | Closed; its git ops were missed | Do its missed git ops |
| `close-missed` | Merged; the close was missed | Close it. The close reconstructs `learned` from the plan and the branch's commits |
| `not-started`, `done`, `dropped` | — | Nothing |

- **Close it** means: invoke `chaining-plans` through the Skill tool with
  `close <effort id> <phase id>`. When it has reported, come back here
  and go on with the row's action.
- **After each row's whole action, run `record.py phase-state` again** (for
  `finished-unclosed`, the whole action is the close and then the git
  ops; check after both, not between them). A settled phase reads
  `done`. If it does not, report what is left and stop.

### Doing a missed git ops

Your human partner's invocation of Resume is their approval for this
merge. You answer the merge menu for them, with their `git ops`: their
own definition when their instructions give one, else the one in
`SKILL.md`. Below, `<branch>` is the phase's `branch` and `<base>` the
record's `base`: write both literally into each command, never through a
shell variable, since a confined worktree may refuse an assignment and a
command in one call.

1. **Find the branch's worktree** in `git worktree list`. If no worktree
   has it, it was built in place: use the main checkout.
2. **Look for an open PR:** `gh pr view <branch> --json state -q .state
   2>/dev/null` prints `OPEN`. Then `git ops` is merging that PR.
3. **No open PR, and `git ops` calls for the push: bring `base` up to
   date, then check the push,** in the main checkout with `base` checked
   out, before anything merges: `git pull --ff-only origin <base>`,
   then `git push --dry-run origin <base>`. For a phase built in place,
   check out `base` for these two, and `<branch>` again after, whether they
   pass or fail. If either fails, that is a refused push: stop now. If
   the pull had already moved `base`, say so in the report: it is a
   fast-forward to `origin`, with nothing to undo. Option 1 deletes the
   branch and removes the worktree before the push, so a push that
   fails after it cannot leave them in place. A dry run does not catch
   server-side hooks or branch protection; those refuse only the real
   push, which still stops, but after the cleanup.
4. **Invoke `finishing-a-development-branch`** fresh through the Skill
   tool, from the branch's worktree, entered as in the `cut-off` row (in
   Claude Code, `EnterWorktree` with its `path`). Give it the record's `base` at its
   Step 3. Its safeguards run as it words them: the full suite before
   the menu, the suite again on the merged result, and its worktree
   cleanup rules.
5. **Answer its menu with `git ops`:**
   - No open PR: option 1. Then, as `git ops` calls for them, push `base`:
     `git -C <main checkout> push origin <base>`. Then delete the
     remote branch, only if `git ls-remote --heads origin <branch>` lists
     it: `git push origin --delete <branch>`.
   - An open PR: `gh pr merge <branch> --merge`, or `--squash` or
     `--rebase` when the repo allows no merge commits (`gh repo view
     --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`).
     Then leave a confined worktree (`ExitWorktree`, action `keep`) and,
     in the main checkout on `base` (for a phase built in place, check
     out `base` first), run `git pull --ff-only origin <base>`, so the
     next phase builds on the merged code. The work has landed, so do
     the cleanup option 1 would have done: remove the branch's worktree
     if it is under `.worktrees/` or `worktrees/`, or under
     `.claude/worktrees/` and this session entered it (`git worktree
     remove <path>`, never `--force`); once `gh pr view <branch> --json state -q
     .state` prints `MERGED`, delete the local branch with
     `git branch -D <branch>` (a squash's branch is never an ancestor of
     `base`, so `-d` refuses it); and delete the remote branch only if
     `git ls-remote --heads origin <branch>` lists it:
     `git push origin --delete <branch>`.

**If any safeguard fails, stop.** That means a red suite, a merge
conflict, a refused worktree removal, a refused push (the dry run or the
real one), or a failed `gh pr merge`. A step that `git ops` calls for
and that fails, such as a configured remote that is unreachable or
refuses the push, is a stop, not a step to skip. (When your human
partner's definition is "the relevant subset" and no remote is
configured, the push is not relevant, and a local merge is correct.)
Report what failed, and leave everything as it is: no force, no other
route, no undoing a merge already made. Your human partner decides what
happens next. Do not pick.

**Report each merge done this way first,** at the top of your first
message to your human partner: the phase, its branch, `base`, and
whether `base` was pushed.

## 4. Pick

Run `record.py pick`. It prints one of:

- **`none`:** every phase is done or dropped. Report that the effort is
  done, and stop.
- **`blocked:<id>`:** report what blocks that phase (each of its
  `depends_on`, with its `phase-state`; a `dropped` dependency will
  never be done), and stop. Your human partner decides.
- **`id:<id>`:** the phase this session runs. Read its `status`:
  - `waiting`: a close should have resolved it, so the record is
    inconsistent. Say so in that word, report the phase, its
    `waits_on`, and the close that should have answered them, and stop.
    Do not design it.
  - `needs-partner`: start at the Intent round.
  - `known`: start at the first stage whose link (`spec`, `plan`) is
    null, else at Build.

## 5. Run the stages straight through to the merge menu

Announce each stage. A stage that names a skill invokes it fresh through
the Skill tool. A stage is done only when its "Done when" holds.

| Stage | What it does | Done when |
|---|---|---|
| Intent round (only if `needs-partner`) | Ask your human partner the `partner_questions` in one round, and end your turn. Fold their answers into the phase's entry in the umbrella's Phases section, commit, then `set` `partner_questions` to `[]` and `status` to `known` | The answers are committed |
| Design (only if no `spec`) | Write the phase's technical design inside its intent. A fresh reviewer reads it with the builder-check prompt. Its technical questions: settle them yourself and log them as rulings. Its intent questions: stop and ask your human partner | The design file is committed and linked |
| Plan (only if no `plan`) | Invoke `writing-plans`, with the standing approval line from `SKILL.md`. Pick the execution method by its recommendation rule, as a ruling | The plan file, with `writing-plans`' header, is committed and linked |
| Build | Invoke the chosen executor. It runs unchanged, with its own four stop conditions | The executor's final message holds "Rulings I made" and "Unfinished", and both are copied into `closing` before finishing starts |
| Finish | Invoke `finishing-a-development-branch`. Your human partner answers its menu | The menu was shown as `finishing` words it, and answered |
| Close | Invoke `chaining-plans` again, to close | `closing.replan` is written and the report given, or, after a discard, `branch` reset and that reported |

**Log rulings as the Design, Plan and Build stages end,** with
`record.py set-closing-key REC <phase id> rulings append`, the stage's
rulings as a JSON list of strings in a value file. It reads `closing`
fresh, starts a null one, and keeps every other key, so nothing is
composed from memory.

### Design

- **No brainstorm.** The umbrella's approval and the intent sitting
  replace it.
- **Inputs:** the whole umbrella, `closing.learned` of every done phase
  (above all the phases in this phase's `waits_on`), and the code on
  `base`. The design copies the phase's Phases entry word for word, with
  the section's "Across phases" line.
- **Where it goes:**
  `docs/superpowers/specs/<phase id>.md`, with first line
  `# <phase id>: <title>`. When the umbrella already
  covers the phase in enough detail, write no design: `spec` links the
  umbrella.
- **The reviewer prompt** is `../brainstorming/builder-check-prompt.md`,
  relative to this skill's base directory (the installed plugin, not the
  project).
- **Commit the design on `base`,** in the main checkout, with the phase
  id in the subject (`docs(K3): design`), then `set` `spec`.

### Plan

- **The plan id is this phase's id.** Tell `writing-plans` so in the
  same message, so the plan is `docs/superpowers/plans/<phase id>.md`
  and its tasks are `<phase id>.1`, `<phase id>.2`, ….
- **Commit the plan on `base` before the build,** with the phase id in
  the subject (`docs(K3): plan`), then `set` `plan`.
  The executor resolves it from inside the worktree.
- **The plan covers this phase only.** When `spec` links the umbrella,
  or a design that other phases share (the parts of a split), tell
  `writing-plans` in the same message which phase it plans: this
  phase's id and its Phases entry, word for word, and that the other
  phases get plans of their own.
- **A further split from `writing-plans`' Scope Check is a re-plan
  ruling,** with no change to intent: split the phase in the record by
  the rules under `set-phases` in `references/record.md`, and commit the
  Phases section to match, on `base`. Every part gets this phase's id
  plus a letter (K3 into `K3a`, `K3b`); the first part takes its `spec`
  and `closing`, and the session goes on as that part: from here on, `id`
  is `K3a`. Log the ruling, and plan the first part with `K3a` as its
  plan id. (K2a, split again, becomes `K2a1` and `K2a2`.)

### Build

- **The worktree preference:** a worktree, unless the project's
  instructions say to build in place. This answers
  `using-git-worktrees`' consent prompt.
- **Building in place,** for a phase whose `branch` is null: in the
  main checkout, on `base`, run `git checkout -b <phase id>` before
  invoking the executor. If a branch of that name exists already, an
  earlier session ended before recording it: when
  `git rev-list --count <base>..<phase id>` prints `0`, check it out
  (unless it is checked out already) and go on; otherwise report it and
  stop. Never implement on `base`. A `cut-off` phase's branch is
  checked out already: re-invoke the executor there, with no
  `checkout -b`.
- **Check that the worktree starts from `base`,** once the executor's
  setup has created it: from inside it, `git merge-base --is-ancestor
  <base> HEAD` exits 0. If it does not, the plan committed on `base` is
  not in the worktree: stop and report that. In Claude Code, the
  worktree starts from `base` only when the setting `worktree.baseRef` is
  `head`.
- **Record `branch` as soon as it exists:** `record.py set` `branch` once
  the executor's setup has created its SDD workspace (its ledger), not
  before, with the name `git branch --show-current` prints in the
  worktree (`worktree-<phase id>` from Claude Code's `EnterWorktree`). A
  branch with no workspace and no commits reads as `close-missed`.
- **Between the executor's final message and finishing,** copy its
  "Rulings I made" into `closing.rulings` and its "Unfinished" into
  `closing.unfinished`, with `record.py set-closing-key`, mode `append`,
  one call per key.
  When an orchestrator subagent ran the plan, copy them from its final
  message.

### Finish

- **Give finishing the record's `base`** at its Step 3.
- The menu is your human partner's. Show it as `finishing` words it, and
  wait.

### Close

- **After the menu is answered,** whatever the answer, invoke the skill
  with `close <effort id> <phase id>`. The close handles each answer, a
  discard included, and hands over. Do not start another phase in this
  session.
