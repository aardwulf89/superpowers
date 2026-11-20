# Resume: the entry prompt

Every session of an effort after Create starts here. Resume settles what
the last session left and picks the next phase. Then it runs that phase
to its merge menu and its close. Run 1 phase per session.

Every command named here is a subcommand of the record script. Run it as
`references/record.md` § Commands says: one plain command per Bash call.
Write the record only in the main checkout, on `base`. Commit every write
before the next stage starts: with the docs commit it belongs to, or
alone as `docs(<id>): record`.

## 1. Find the record

- **An effort id was given** (as the argument, or in the request): the
  record is `docs/superpowers/efforts/<id>.json` of the main checkout. If
  the file is missing, say so and stop.
- **No id:** run `record.py open-efforts`.
  - If it prints nothing, say that there is no open effort, and that an
    effort starts with Create. Stop.
  - If it prints 1 path, use it.
  - If it prints several, list them by effort id. Ask your human partner
    which one, and end your turn. Do not pick one for them.

The effort id is the record file's name, without `.json`. Every later
command takes the record's absolute path as its `REC` argument.

## 2. Check git

- **Work in the main checkout:** the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. If the session
  started in a worktree, `cd` there. An isolated worktree (Claude Code,
  after `EnterWorktree`) cannot `cd` out: leave it with `ExitWorktree`,
  action `keep`.
- **A clean tree:** `git status --porcelain` prints nothing. If it prints
  anything, report the files and stop. They are your human partner's
  work in progress.
- **On `base`:** the main checkout has the record's `base` checked out.
  The 1 exception is a phase built in place: its own branch,
  `<phase id>`, can be checked out. If another branch is checked out,
  report it and stop.
- **`base` up to date:** if the repo has a remote `origin`, update `base`
  before you settle anything. Then a PR merged on the forge reads as
  merged (its `<phase id>.build.json` reaches `base`), and Resume does
  not merge it again or rebuild it.
  - If `base` is checked out, run `git pull --ff-only origin <base>`.
  - If a phase's own branch is checked out, run
    `git fetch origin <base>:<base>`.
  - Both commands move `base` only by a fast-forward. If the command
    refuses because `base` and `origin` diverged, report both tips
    and stop. Your human partner decides. Never merge or rebase `base`
    yourself.
  - If `origin` cannot be reached, say so in the report. Continue with
    the local `base`.

## 3. Settle every phase under way

Do this before the pick: `pick` reports a phase that is under way as
`blocked:`.

For each phase, in array order, run `record.py phase-state`. Do the
action for the state it prints:

| State | What happened | Action |
|---|---|---|
| `cut-off` | The build was cut off. Its SDD workspace exists | This phase is this session's phase. Go to the Build stage (step 6). Enter the branch's worktree (`git worktree list`; in Claude Code, `EnterWorktree` with its `path`). Re-invoke the executor there: it resumes from its own ledger. Then run the stages after Build. Do not pick |
| `finished-unclosed` | Finished; not closed, not merged | Close it. Then do its missed git ops |
| `closed-unmerged` | Closed; its git ops were missed | Do its missed git ops |
| `close-missed` | Merged; the close was missed | Close it |
| `anomaly` | The phase branch has commits but no workspace and no build results file, or both branch names exist | Report the branch or branches, their commits, and any worktree that has them. Stop. A session was likely cut off after the executor deleted its workspace and before the build's results were committed, so the build's rulings are lost. Your human partner decides what happens to the branch |
| `not-started`, `done`, `dropped` | — | Nothing |

- **Tasks:** before you do the action of a row other than `cut-off`, make
  1 step task with `TaskCreate` for each part of the action. Name them as
  `SKILL.md` § Tasks says: "Missed close (A2)", "Missed git ops (A2)".
  Block each Missed git ops task by the Missed close task of its phase,
  with `TaskUpdate` (`addBlockedBy`). Set each task's status as step 6
  says.
- **Close it** means: invoke `chaining-plans` through the Skill tool with
  `close <effort id> <phase id>`. When the close reports back, come back
  here and continue with the row's action.
- **After the whole action of each row, run `record.py phase-state`
  again.** For `finished-unclosed`, the whole action is the close and
  then the git ops: check after both, not between them. A settled phase
  reads `done`. If it does not, report what is left and stop.

### Missed git ops

Your human partner's invocation of Resume is their approval for this
merge. Answer the merge menu for them with their `git ops`: their own
definition if their instructions give one, else the one in `SKILL.md`.

Below, `<branch>` is the phase's branch that exists: `worktree-<phase id>`,
or `<phase id>` for a phase built in place. `<base>` is the record's
`base`. Write both literally into each command, never through a shell
variable: an isolated worktree can refuse a call that holds an
assignment and a command.

1. **Find the branch's worktree** in `git worktree list`.
   - A `<phase id>` branch that no worktree has was built in place. Use
     the main checkout.
   - But a `worktree-<phase id>` branch that no worktree has is missing its
     worktree. Report it and stop: finishing from the main checkout
     tests and merges `base`, not the branch.
2. **Look for an open PR.** If
   `gh pr view <branch> --json state -q .state 2>/dev/null` prints `OPEN`,
   `git ops` means: merge that PR.
3. **If there is no open PR and `git ops` calls for the push, check the
   push before anything merges.** Step 2 already updated `base`. In the
   main checkout, with `base` checked out, run
   `git push --dry-run origin <base>`. For a phase built in place, check
   out `base` for this command, and `<branch>` again after it. If it
   fails, that is a refused push: stop now. Check before the merge
   because option 1 deletes the branch and removes the worktree before it
   pushes.
4. **Invoke `finishing-a-development-branch`** fresh through the Skill
   tool, from the branch's worktree. Enter the worktree as in the
   `cut-off` row (in Claude Code, `EnterWorktree` with its `path`). Give
   finishing the record's `base` at its Step 3. Its safeguards run as it
   words them: the full suite before the menu, the suite again on the
   merged result, and its worktree cleanup rules.
5. **Answer its menu with `git ops`:**
   - **No open PR:** choose option 1. Then, if `git ops` calls for it,
     push `base`: `git -C <main checkout> push origin <base>`. Then
     delete the remote branch, only if
     `git ls-remote --heads origin <branch>` lists it:
     `git push origin --delete <branch>`.
   - **An open PR:**
     1. Run `gh pr merge <branch> --merge`. If the repo allows no merge
        commits, use `--squash` or `--rebase` instead (`gh repo view
        --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`).
     2. Leave an isolated worktree (`ExitWorktree`, action `keep`).
     3. In the main checkout on `base`, run
        `git pull --ff-only origin <base>`, so the next phase builds on
        the merged code. For a phase built in place, check out `base`
        first.
     4. Do the cleanup that option 1 does. If the branch's worktree is
        under `.worktrees/` or `worktrees/`, or under
        `.claude/worktrees/` and this session entered it, remove it
        with `git worktree remove <path>`, never `--force`. If the
        removal is refused, follow `finishing-a-development-branch`'s
        Step 6, its lock rule included.
     5. When `gh pr view <branch> --json state -q .state` prints
        `MERGED`, delete the local branch with `git branch -D <branch>`.
        Use `-D`: a squash's branch is never an ancestor of `base`, so
        `-d` refuses it.
     6. Delete the remote branch only if
        `git ls-remote --heads origin <branch>` lists it:
        `git push origin --delete <branch>`.

**If any safeguard fails, stop.** That means a red suite, a merge
conflict, or a failed `gh pr merge`. It also means a refused worktree
removal or a refused push (the dry run or the real one). A step that
`git ops` calls for and that fails is a stop, not a step to skip. An
example is a configured remote that is unreachable or refuses the push.
When your human partner's definition is "the relevant subset" and no
remote is configured, the push is not relevant, and a local merge is
correct.
Report what failed, and leave everything as it is: no force, no other
route, no undoing a merge already made. Your human partner decides what
happens next. Do not pick.

**Report each merge done this way first,** at the top of your first
message to your human partner: the phase, its branch, `base`, and
whether you pushed `base`.

### Answers given outside a round

Your human partner can answer at any time: in the request, or between
stages. Fold in each such answer at once, before the pick or the next
stage:

- **Write it** into the "Answers:" line of the raising phase's entry in
  the Phases section. For a question, that is the phase that asks it.
  Commit it on `base`, in the main checkout.
- **A partner item answered this way** gets `[settled: <raising phase id>]`
  at the very end of its line. Write it as the Intent round writes it
  (step 6).
- **Then run `close.md` step 2,** as the Intent round's last bullet says.
  Before the pick, this session has no phase yet: log the changes as
  rulings of the raising phase.

## 4. Pick

Run `record.py pick`. It prints 1 of these:

- **`none`:** every phase is done or dropped, and every partner item has
  a disposition. Give the last message of step 5, and stop.
- **`items`:** every phase is done or dropped, and some partner item is
  open. Go to step 5.
- **`blocked:<id>`:** report what blocks that phase: each of its
  `depends_on`, with its `phase-state`. A `dropped` dependency will
  never be done. Stop. Your human partner decides.
- **`id:<id>`:** this session runs that phase. Read its `status`:
  - `waiting`: a close was meant to resolve it, so the record is
    inconsistent. Say so with that word. Report the phase, its
    `waits_on`, and the close that was meant to answer them. Stop. Do
    not design it.
  - `needs-partner`: start at the Intent round.
  - `known`: start at the first stage whose link (`spec`, `plan`) is
    null. If both links are set, start at Build.

## 5. The end of the effort

Every phase is done or dropped. The effort is closed out only when every
partner item has a disposition and none is `[carried]`. Only your human
partner gives a disposition.

**Read the items.** For every phase, a dropped one included, run
`record.py get REC <phase id> closing`. A partner item is an
`unfinished` line that starts with `Partner item: `. It is open if it
ends in none of the 4 suffixes of `references/record.md`:
`[settled: <phase id>]`, `[dropped]`, `[carried]`,
`[adopted by <phase id>]`.

### The end round (`items`)

- **A disposition that your human partner already gave,** in the request
  or earlier in this session, is their answer to that item. Apply it as
  below. Do not ask it again.
- **Ask for the rest in 1 round.** Show every open item, with its phase,
  its options and its interim default. Ask for a disposition of each:
  settle it (with the answer), drop it, or carry it past this effort.
  Then end your turn. The message starts:

  ```
  Effort <id>'s phases are all done, but the effort is not closed out: <n> items need your disposition.
  ```

  For 1 item, write `1 item needs`.

- **Only your human partner's words decide a disposition.** Haste is not
  a disposition: "wrap it up", "finish the effort" or "I'm in a hurry"
  settles, drops and carries nothing. Ask the round anyway. Never pick a
  disposition for them, not even the interim default.

### The answers

- **Settle:** fold the answer into the "Answers:" line of the raising
  phase's entry in the Phases section. Commit it on `base`, in the main
  checkout (`docs(<phase id>): answer a partner item`). The line's
  suffix is `[settled: <raising phase id>]`.
- **Drop:** the suffix is `[dropped]`. **Carry:** the suffix is
  `[carried]`.
- **Write the suffixes** per phase:
  1. Read `record.py get REC <phase id> closing` fresh.
  2. Add each suffix at the very end of its line, after 1 space.
  3. Write the whole list to a value file.
  4. Run `record.py set-closing-key REC <phase id> unfinished replace
     --value-file <path>`.
- **An answer that calls for work** is a settle: fold it into the
  raising phase's "Answers:" line, and give the line
  `[settled: <raising phase id>]`, as above. Then add a phase for the
  work, as a re-plan that your human partner directs. Follow the rules
  under `set-phases` in `references/record.md`. The new phase's Phases
  entry carries the work. Commit the Phases section to match, on `base`.
  Then pick again (step 4).
- **If items are still open** after the answers, ask for those in a new
  round, as above.
- **If no item is open,** give the last message.

### The last message

Count the lines of every phase: the `[carried]` ones, the `[settled: …]`
ones and the `[dropped]` ones. The message starts with 1 of 2 first
lines, word for word, with `<id>` and `<n>` filled in. For 1 carried
item, write its lines in the singular: `1 item stays open`, `It is`,
`show it`.

- **Some line is `[carried]`:**

  ```
  Effort <id> is finished, but NOT closed out: <n> items stay open, carried past this effort.
  They are in the effort's record, docs/superpowers/efforts/<id>.json, committed on <base>.
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

When an item is carried, never call the effort closed out.

## 6. Run the stages straight through to the merge menu

Announce each stage. If a stage names a skill, invoke the skill fresh
through the Skill tool. A stage is done only when its "Done when" holds.
If your human partner answers between stages, fold in the answer as
`### Answers given outside a round` (step 3) says.

Before you start the first stage, make 1 step task with `TaskCreate` for
each stage that this session runs, as `SKILL.md` § Tasks says. Title it
`<stage> (<phase id>)` ("Design (A3)"). Do not make 1 task for 2 or more
stages ("A3 Design → Plan → Build → Finish → Close").

Do not make a task for a stage that does not run:
- The Intent round, if `status` is not `needs-partner`.
- Design, if `spec` is not null.
- Plan, if `plan` is not null.

If Design starts an Intent round, make the task for that round when the
round starts.

- Set each task's `activeForm` ("Building A3").
- Block each task by the stage task before it, with `TaskUpdate`
  (`addBlockedBy`). Block the first task by every task of step 3. An
  Intent round that Design starts has no blocker.
- Set a task in_progress when its stage starts. Mark it completed only
  when its "Done when" holds. A task stays in_progress while its stage
  waits on your human partner or is stopped.

| Stage | What it does | Done when |
|---|---|---|
| Intent round (only if `needs-partner`) | Ask your human partner the `partner_questions` in 1 round, and end your turn. Fold their answers into the phase's entry in the Phases section, and commit. Then `set` `partner_questions` to `[]` and `status` to `known`. Then settle the partner items that the questions came from (below) | The answers are committed |
| Design (only if no `spec`) | Write the phase's technical design inside its intent. Use the interim default of each open partner item that bears on it. A fresh reviewer reads the design with the builder-check prompt. Settle its technical questions yourself, and log them as rulings. For its intent questions, stop and ask your human partner | The design file is committed and linked |
| Plan (only if no `plan`) | Invoke `superpowers-extended-cc:writing-plans`, with the standing approval line from `SKILL.md`. The standing approval answers its handoff: Subagent-Driven (this session). Log that as a ruling | The plan and its tasks file are committed on `base` and linked |
| Build | Invoke `superpowers-extended-cc:subagent-driven-development`. It runs unchanged, with its own 4 stop conditions | The executor's final message holds "Rulings I made" and "Unfinished", and `<phase id>.build.json`, which holds both, is committed on the phase branch before finishing starts |
| Finish | Invoke `finishing-a-development-branch`. Your human partner answers its menu | The menu was shown as `finishing` words it, and answered |
| Close | Invoke `chaining-plans` again, to close | `closing.replan` is written and the report given, or, after a discard, the discard reported |

**Log rulings as the Design and Plan stages end.** In the main checkout,
run `record.py set-closing-key REC <phase id> rulings append`, with the
stage's rulings as a JSON list of strings in a value file. Commit the
record with the stage's docs commit, or alone as
`docs(<phase id>): record` (`references/record.md`). The Build stage's
rulings go in `<phase id>.build.json` instead (Build, below).

### Intent round

- **A question that came from a partner item settles that item.** The
  item's line is in the raising phase's `unfinished`, and holds
  `→ partner_questions of <this phase's id>`. After the answers are
  committed, add `[settled: <this phase's id>]` at the very end of that
  line. That id names the phase whose "Answers:" line now holds the
  answer. To write it:
  1. Read `record.py get REC <raising phase id> closing`.
  2. Write the whole list from a value file with
     `record.py set-closing-key REC <raising phase id> unfinished replace`.

  The answer is your human partner's, so this is not a disposition that
  you give.
- **When you fold in any answer, run `close.md` step 2** over the phases
  that are not done, other than this one: they can rest on the old
  default. Log each change as a ruling of this phase
  (`set-closing-key … rulings append`). Write no `replan`: that write
  belongs to the close.

### Design

- **No brainstorm.** The umbrella's approval and the intent sitting
  replace it.
- **Inputs:**
  - the whole umbrella;
  - `closing.learned` of every done phase, above all the phases in this
    phase's `waits_on`;
  - the open partner items of every phase, a dropped one included
    (step 5, "Read the items", says which items are open);
  - the code on `base`.
- **Copy the phase's Phases entry** into the design word for word, with
  the section's "Across phases" line.
- **If an open partner item bears on the phase,** write its interim
  default in the design. Cite the item's phase and text. Do not log the
  default: following a default is not a ruling.
- **If you find that an item changes the phase's intent:**
  1. Add the item to this phase's `partner_questions`. Read the list with
     `record.py get REC <phase id> partner_questions`, then `set` it with
     the item added, from a value file.
  2. `set` `status` to `needs-partner`.
  3. Add a pointer at the end of the item's original line:
     `→ partner_questions of <phase id>`. Write the line as the Intent
     round above does.
  4. Run the Intent round. It asks the item, and ends your turn.
- **Where it goes:** `docs/superpowers/specs/<phase id>.md`, with first
  line `# <phase id>: <title>`. If the umbrella already covers the phase
  in enough detail, write no design: `spec` links the umbrella.
- **The reviewer prompt** is `../brainstorming/builder-check-prompt.md`,
  relative to this skill's base directory (the installed plugin, not the
  project).
- **Commit the design on `base`,** in the main checkout, with the phase
  id in the subject (`docs(K3): design`). Then `set` `spec`.

### Plan

- **The plan id is this phase's id.** Tell `writing-plans` this in the
  same message. Then the plan is `docs/superpowers/plans/<phase id>.md`
  and its tasks are `<phase id>.1`, `<phase id>.2`, ….
- **Commit the plan and its tasks file on `base` before the build.**
  `writing-plans` commits `docs/superpowers/plans/<phase id>.md` and
  `<phase id>.md.tasks.json` together. Tell it the subject
  (`docs(<phase id>): plan`). Check that the commit holds both files.
  Then `set` `plan` and commit the record.
- **The plan covers this phase only.** If `spec` links the umbrella, or
  a design that other phases share (the parts of a split), tell
  `writing-plans` in the same message which phase it plans. Give this
  phase's id and its Phases entry, word for word. Say that the other
  phases get plans of their own.
- **A further split from the Scope Check of `writing-plans` is a re-plan
  ruling,** with no change to intent:
  1. Split the phase in the record by the rules under `set-phases` in
     `references/record.md`. Commit the Phases section to match, on
     `base`.
  2. Continue the session as the first part. If K3 splits into `K3a` and
     `K3b`, from here on `id` is `K3a`.
  3. Retitle each stage task that is not completed, and its `activeForm`,
     with `TaskUpdate` ("Build (K3)" → "Build (K3a)", "Building K3" →
     "Building K3a").
  4. Log the ruling.
  5. Plan the first part, with `K3a` as its plan id.

### Build

- **The worktree preference:** a worktree, unless the project's
  instructions say to build in place. This answers
  `using-git-worktrees`' consent prompt.
- **In place, for a `not-started` phase:** in the main checkout, on
  `base`, run `git checkout -b <phase id>` before you invoke the
  executor. If a branch of that name exists already, it has no commits of
  its own (else `phase-state` reads `anomaly`): check it out and
  continue. Never implement on `base`.
- **In place, for a `cut-off` phase:** its branch is checked out
  already. Re-invoke the executor there, with no `checkout -b`.
- **In a worktree, for a `not-started` phase:** the executor's setup
  creates the worktree with `EnterWorktree`, named by the phase id, so
  its branch is `worktree-<phase id>`. Before you invoke the executor,
  look for that worktree in `git worktree list`, from the main checkout.
  If it exists and `git -C <its path> status --porcelain` prints
  anything, report the files and stop: they were never committed.
- **Check the branch name** after the executor's setup creates it:
  `git branch --show-current` in the worktree prints
  `worktree-<phase id>` (`<phase id>` in place). If it prints another
  name, stop and report it: `phase-state` and the close find the branch
  by that name.
- **Between the executor's final message and finishing, write the build
  results file:**
  1. Write the executor's "Rulings I made" and "Unfinished" to
     `docs/superpowers/plans/<phase id>.build.json`, as
     `{"rulings": [...], "unfinished": [...]}`. Use JSON lists of
     strings, each line as the message words it, and an empty list for
     a section that has no lines. Use the Write tool, in the working
     tree you built in. If an orchestrator subagent ran the plan, take
     the lists from its final message.
  2. Commit the file on the phase branch, one plain command per call:
     `git add` the file, then
     `git commit -m "docs(<phase id>): build results"`.
  3. Mark the Build task completed.

  In an isolated worktree, this file is the only write the chain makes.
  Never write the record from inside the worktree: it lives in the main
  checkout.

### Finish

- **Give finishing the record's `base`** at its Step 3.
- The menu is your human partner's. Show it as `finishing` words it, and
  wait.

### Close

- **After the menu is answered,** whatever the answer, invoke the skill
  with `close <effort id> <phase id>`. The close handles each answer, a
  discard included, and hands over. Do not start another phase in this
  session.
