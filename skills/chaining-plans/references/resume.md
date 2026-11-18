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
  phase built in place, or a branch named `<phase id>` for a phase whose
  `branch` is still null (a session ended before recording it; the Build
  stage reuses it). Anything else: report it and stop.

## 3. Settle every phase under way

Do this before the pick: `pick` reports a phase that is under way as
`blocked:`.

For each phase, in array order, run `record.py phase-state` and act on what it
prints:

| State | What happened | Action |
|---|---|---|
| `cut-off` | The build was cut off; its SDD workspace exists | This phase is this session's phase. Go to the Build stage (step 6): enter the branch's worktree (`git worktree list`; in Claude Code, `EnterWorktree` with its `path`) and re-invoke the executor there. It resumes from its own ledger. Run the stages after it, and do not pick |
| `finished-unclosed` | Finished; not closed, not merged | Close it, then do its missed git ops |
| `closed-unmerged` | Closed; its git ops were missed | Do its missed git ops |
| `close-missed` | Merged; the close was missed | Close it. The close reconstructs `learned` from the plan and the branch's commits |
| `not-started`, `done`, `dropped` | — | Nothing |

- **Tasks:** before the action of a row other than `cut-off`, use
  `TaskCreate` to make one task for each of its parts: "A2: Missed close",
  "A2: Missed git ops". Block the Missed git ops task by its phase's Missed
  close task, with `TaskUpdate` (`addBlockedBy`). Status as in step 6.
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

### Answers given outside a round

Your human partner may answer at any time: in the request, or between
stages. Fold each such answer in at once, before the pick or the next
stage:

- **Write it** into the "Answers:" line of the raising phase's entry in
  the umbrella's Phases section (for a question, of the phase that asks
  it), and commit it on `base`, in the main checkout.
- **A partner item answered so** gets `[settled: <raising phase id>]` at
  the very end of its line, written as the Intent round writes it (step
  6).
- **Then run `close.md` step 2,** as the Intent round's last bullet says.
  Before the pick there is no phase of this session yet: log the changes
  as rulings of the raising phase.

## 4. Pick

Run `record.py pick`. It prints one of:

- **`none`:** every phase is done or dropped, and every partner item has
  a disposition. Give the last message of step 5, and stop.
- **`items`:** every phase is done or dropped, and some partner item is
  open. Go to step 5.
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

## 5. The end of the effort

Every phase is done or dropped. The effort is closed out only when every
partner item has a disposition and none is `[carried]`. Only your human
partner gives a disposition.

**Read the items.** For every phase, a dropped one included, run
`record.py get REC <phase id> closing`. A partner item is an
`unfinished` line that starts with `Partner item: `. It is open when it
ends in none of the four suffixes of `references/record.md`:
`[settled: <phase id>]`, `[dropped]`, `[carried]`,
`[adopted by <phase id>]`.

### The end round (`items`)

- **A disposition your human partner already gave,** in the request or
  earlier in this session, is their answer to that item: apply it as
  below, and do not ask it again.
- **Ask for the rest in one round.** Show every open item, with its
  phase, its options and its interim default. Ask for a disposition of
  each: settle it (with the answer), drop it, or carry it past this
  effort. Then end your turn. The message starts:

  ```
  Effort <id>'s phases are all done, but the effort is not closed out: <n> items need your disposition.
  ```

  For one item, write `1 item needs`.

- **Only your human partner's words decide a disposition.** Haste is not
  one: "wrap it up", "finish the effort" or "I'm in a hurry" settles,
  drops and carries nothing, so ask the round anyway. Never pick a
  disposition for them, not even the interim default.

### The answers

- **Settle:** fold the answer into the "Answers:" line of the raising
  phase's entry in the umbrella's Phases section, and commit it on
  `base`, in the main checkout (`docs(<phase id>): answer a partner
  item`). The line's suffix is `[settled: <raising phase id>]`.
- **Drop:** the suffix is `[dropped]`. **Carry:** the suffix is
  `[carried]`.
- **Write the suffixes** per phase: read `record.py get REC <phase id>
  closing` fresh, add each suffix at the very end of its line, after one
  space, and write the whole list to a value file. Then run
  `record.py set-closing-key REC <phase id> unfinished replace
  --value-file <path>`.
- **An answer that calls for work** is a settle: fold it into the
  raising phase's "Answers:" line, and give the line
  `[settled: <raising phase id>]`, as above. Then add a phase for the
  work, as a re-plan your human partner directs: follow the rules under
  `set-phases` in `references/record.md`. The new phase's Phases entry
  carries the work. Commit the Phases section to match, on `base`. Then
  pick again (step 4).
- **Items still open** after the answers: ask for those in a new round,
  as above.
- **None open:** give the last message.

### The last message

Count the lines of every phase: the `[carried]` ones, the `[settled: …]`
ones and the `[dropped]` ones. The message leads with one of two first
lines, word for word, with `<id>` and `<n>` filled in. For one carried
item, write its lines in the singular: `1 item stays open`, `It lives`,
`show it`.

- **Some line is `[carried]`:**

  ```
  Effort <id> is finished, but NOT closed out: <n> items stay open, carried past this effort.
  They live only in this machine's record (.superpowers/chain/<id>/effort.json), not in the repo.
  The next effort's Create in this repo will show them to you. Work done outside chaining-plans will not.

  Carried:
  1. [<phase id>] <the item, with its interim default>
  2. ...
  Settled: <n> (answers in the umbrella, section Phases). Dropped: <n>.
  ```

  List every carried item.

- **No line is `[carried]`:**

  ```
  Effort <id> is closed out: every phase is done or dropped, and no item is open.
  ```

Never call the effort closed out when an item is carried.

## 6. Run the stages straight through to the merge menu

Announce each stage. A stage that names a skill invokes it fresh through
the Skill tool. A stage is done only when its "Done when" holds. An
answer your human partner gives between stages is folded in as
`### Answers given outside a round` (step 3) says.

Before you start the first stage, use `TaskCreate` to make one task for
each stage that this session runs. Title it `<phase id>: <stage>`
("A3: Design"). Do not make one task for two or more stages
("A3 Design → Plan → Build → Finish → Close").

Do not make a task for a stage that does not run:
- The Intent round, if `status` is not `needs-partner`.
- Design, if `spec` is not null.
- Plan, if `plan` is not null.

If Design starts an Intent round, make the task for that round when the
round starts.

Set each task's `activeForm` ("Building A3"). Block each task by the
stage task before it, with `TaskUpdate` (`addBlockedBy`). Block the first
by every task of step 3. An Intent round that Design starts has no blocker.
Set a task in_progress when its stage starts. Mark it completed only when
its "Done when" holds. A task stays in_progress while its stage waits on
your human partner or has stopped.

| Stage | What it does | Done when |
|---|---|---|
| Intent round (only if `needs-partner`) | Ask your human partner the `partner_questions` in one round, and end your turn. Fold their answers into the phase's entry in the umbrella's Phases section, commit, then `set` `partner_questions` to `[]` and `status` to `known`. Then settle the partner items the questions came from (below) | The answers are committed |
| Design (only if no `spec`) | Write the phase's technical design inside its intent, on the interim default of each open partner item that bears on it. A fresh reviewer reads it with the builder-check prompt. Its technical questions: settle them yourself and log them as rulings. Its intent questions: stop and ask your human partner | The design file is committed and linked |
| Plan (only if no `plan`) | Invoke `writing-plans`, with the standing approval line from `SKILL.md`. Pick the execution method by its recommendation rule, as a ruling | The plan file, with `writing-plans`' header, is committed and linked |
| Build | Invoke the chosen executor. It runs unchanged, with its own four stop conditions | The executor's final message holds "Rulings I made" and "Unfinished", and both are copied into `closing` before finishing starts |
| Finish | Invoke `finishing-a-development-branch`. Your human partner answers its menu | The menu was shown as `finishing` words it, and answered |
| Close | Invoke `chaining-plans` again, to close | `closing.replan` is written and the report given, or, after a discard, `branch` reset and that reported |

**Log rulings as the Design, Plan and Build stages end,** with
`record.py set-closing-key REC <phase id> rulings append`, the stage's
rulings as a JSON list of strings in a value file. It reads `closing`
fresh, starts a null one, and keeps every other key, so nothing is
composed from memory.

### Intent round

- **A question that came from a partner item** settles that item. Its
  line is in the raising phase's `unfinished`, and holds
  `→ partner_questions of <this phase's id>`. Once the answers are
  committed, add `[settled: <this phase's id>]` at the very end of that
  line, which names the phase whose "Answers:" line now holds the
  answer: read `record.py get REC <raising phase id> closing`, and write
  the whole list from a value file with
  `record.py set-closing-key REC <raising phase id> unfinished replace`.
  The answer is your human partner's, so this is not a disposition you
  give.
- **Folding in any answer runs `close.md` step 2** over the phases that
  are not done, other than this one: they may rest on the old default.
  Log each change as a ruling of this phase (`set-closing-key … rulings
  append`), and write no `replan`: that write is the close's.

### Design

- **No brainstorm.** The umbrella's approval and the intent sitting
  replace it.
- **Inputs:** the whole umbrella, `closing.learned` of every done phase
  (above all the phases in this phase's `waits_on`), the open partner
  items of every phase, a dropped one included, and the code on `base`.
  An open partner item is an `unfinished` line of
  `record.py get REC <phase id> closing` that starts with
  `Partner item: ` and ends in no disposition suffix. The design copies
  the phase's Phases entry word for word, with the section's "Across
  phases" line.
- **An open partner item that bears on the phase:** the design writes
  its interim default, and cites the item's phase and text. Following
  the default is not a ruling: do not log it.
- **An item found to change the phase's intent** goes into this phase's
  `partner_questions` (read the list with `record.py get REC <phase id>
  partner_questions`, then `set` it with the item added, from a value
  file), and `status` becomes `needs-partner`. Its original line gets a
  pointer at its end: `→ partner_questions of <phase id>`, written as
  in the Intent round above. Then run the Intent round: it asks the
  item, and ends your turn.
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
  is `K3a`. Retitle each stage task that is not completed, and its `activeForm`,
  with `TaskUpdate` ("K3: Build" → "K3a: Build"). Log the ruling, and plan
  the first part with `K3a` as its plan id. (K2a, split again, becomes `K2a1` and `K2a2`.)

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
- **Building in a worktree,** for a phase whose `branch` is null: before
  invoking the executor, from the main checkout, look for what an
  earlier session left when it ended before recording `branch`: a branch
  `worktree-<phase id>` (`git branch --list worktree-<phase id>`), and the
  worktree that has it checked out (`git worktree list`). Claude Code's
  `EnterWorktree`, given the same name, resumes it as-is when the worktree
  exists, and resets the branch to `base` when only the branch is left,
  so its commits would be lost. Go on only when
  `git rev-list --count <base>..worktree-<phase id>` prints `0` and that
  worktree, if any, has a clean `git -C <its path> status --porcelain`.
  Otherwise report the branch, its commits and any uncommitted files,
  and stop. Your human partner decides what happens to them.
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
