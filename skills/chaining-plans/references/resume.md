# Resume: the entry prompt

Every session of an effort after Create starts here. Resume settles what
the last session left, picks the next phase, and runs that one phase
straight through to its merge menu and its close. One phase per session.

Every block named here is in `references/record.md`. Run it as written,
with its inputs assigned in the same Bash call.

## 1. Find the record

- **An effort id was given** (as the argument, or in the request): the
  record is `<chain_dir>/<id>/effort.json`. Run `chain-dir` to find
  `chain_dir`. If the file is missing, say so and stop.
- **No id:** run `open-efforts`.
  - Nothing printed: say there is no open effort, and that an effort
    starts with Create. Stop.
  - One path: use it.
  - Several: list them by effort id, ask your human partner which one,
    and end your turn. Do not pick one for them.

The effort id is the name of the record's directory. Every later block
gets `rec=<path to effort.json>`.

## 2. Check git

- **Work in the main checkout:** the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. If the session
  started in a worktree, `cd` there.
- **A clean tree:** `git status --porcelain` prints nothing. If it prints
  anything, report the files and stop. They are your human partner's
  work in progress.
- **On `base`:** the main checkout has the record's `base` checked out,
  unless a phase built in place has its branch checked out there.
  Anything else: report it and stop.

## 3. Settle every phase under way

Do this before the pick: `pick` reports a phase that is under way as
`blocked:`.

For each phase, in array order, run `phase-state` and act on what it
prints:

| State | What happened | Action |
|---|---|---|
| `cut-off` | The build was cut off; its SDD workspace exists | This phase is this session's phase. Go to the Build stage (step 5): re-invoke the executor in the branch's worktree (`git worktree list`). It resumes from its own ledger. Run the stages after it, and do not pick |
| `finished-unclosed` | Finished; not closed, not merged | Close it, then do its missed git ops |
| `closed-unmerged` | Closed; its git ops were missed | Do its missed git ops |
| `close-missed` | Merged; the close was missed | Close it. The close reconstructs `learned` from the plan and the branch's commits |
| `not-started`, `done`, `dropped` | — | Nothing |

- **Close it** means: invoke `chaining-plans` through the Skill tool with
  `close <effort id> <phase id>`. When it has reported, come back here
  and go on settling.
- **After each action, run `phase-state` again.** A settled phase reads
  `done`. If it does not, report what is left and stop.

### Doing a missed git ops

Your human partner's invocation of Resume is their approval for this
merge. You answer the merge menu for them, with their `git ops`. Set `b`
to the phase's `branch` and `base` to the record's `base`.

1. **Find the branch's worktree** in `git worktree list`. If no worktree
   has it, it was built in place: use the main checkout.
2. **Look for an open PR:** `gh pr view "$b" --json state -q .state
   2>/dev/null` prints `OPEN`. Then `git ops` is merging that PR.
3. **No open PR: bring `base` up to date, then check the push,** in the
   main checkout with `base` checked out, before anything merges:
   `git pull --ff-only origin "$base"`, then
   `git push --dry-run origin "$base"`. For a phase built in place,
   check out `base` for these two and `"$b"` again after. If either
   fails, or there is no `origin` to run them against, that is a refused
   push: stop now. Run both; never skip one. Option 1 deletes the branch
   and removes the worktree before the push, so a push that fails after
   it cannot leave them in place. A dry run does not catch server-side
   hooks or branch protection; those refuse only the real push, which
   still stops, but after the cleanup.
4. **Invoke `finishing-a-development-branch`** fresh through the Skill
   tool, from the branch's worktree. Give it the record's `base` at its
   Step 3. Its safeguards run as it words them: the full suite before
   the menu, the suite again on the merged result, and its worktree
   cleanup rules.
5. **Answer its menu with `git ops`:**
   - No open PR: option 1. Then push `base`:
     `git -C <main checkout> push origin "$base"`. Then delete the
     remote branch, only if `git ls-remote --heads origin "$b"` lists
     it: `git push origin --delete "$b"`.
   - An open PR: `gh pr merge "$b"`, with a merge method the repo
     allows. Then `git -C <main checkout> pull` on `base`, so the next
     phase builds on the merged code.

**If any safeguard fails, stop.** That means a red suite, a merge
conflict, a refused worktree removal, a refused push (the dry run or the
real one), or a failed `gh pr merge`. A part of `git ops` that cannot
run, such as a push with no remote, is a failure too, not a step to
skip: your human partner is away for this merge, so it is the whole of
`git ops` or none of it. Only they can narrow it. Report what failed,
and leave everything as it is: no force, no other route, no undoing a
merge already made. Your human partner decides what happens next. Do not
pick.

**Report each merge done this way first,** at the top of your first
message to your human partner: the phase, its branch, `base`, and that
`base` was pushed.

## 4. Pick

Run `pick`. It prints one of:

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
    null.

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
| Close | Invoke `chaining-plans` again, to close | `closing.replan` is written and the report given |

**Log rulings as each stage ends.** Add the stage's rulings to
`closing.rulings` with `set`: `field=closing`, and the whole object as
`value_json` (the current `rulings` plus the new ones, `unfinished` as
it is, `learned` and `replan` null). A null `closing` starts as
`{"rulings": [...], "unfinished": [], "learned": null, "replan": null}`.

### Design

- **No brainstorm.** The umbrella's approval and the intent sitting
  replace it.
- **Inputs:** the whole umbrella, `closing.learned` of every done phase
  (above all the phases in this phase's `waits_on`), and the code on
  `base`. The design copies the phase's Phases entry word for word, with
  the section's "Across phases" line.
- **Where it goes:**
  `docs/superpowers/specs/<date>-<umbrella topic>-<phase id>-design.md`,
  with today's date and the umbrella's topic. When the umbrella already
  covers the phase in enough detail, write no design: `spec` links the
  umbrella.
- **The reviewer prompt** is `../brainstorming/builder-check-prompt.md`,
  relative to this skill's base directory (the installed plugin, not the
  project).
- **Commit the design on `base`,** in the main checkout, then `set`
  `spec`.

### Plan

- **Commit the plan on `base` before the build,** then `set` `plan`.
  The executor resolves it from inside the worktree.
- **A further split from `writing-plans`' Scope Check is a re-plan
  ruling,** with no change to intent: split the phase in the record, log
  the ruling, and plan the first part.

### Build

- **The worktree preference:** a worktree, unless the project's
  instructions say to build in place. This answers
  `using-git-worktrees`' consent prompt.
- **Record `branch` as soon as it exists:** `set` `branch` once the
  executor's setup has created its SDD workspace (its ledger), not
  before. A branch with no workspace and no commits reads as
  `close-missed`.
- **Between the executor's final message and finishing,** copy its
  "Rulings I made" into `closing.rulings` and its "Unfinished" into
  `closing.unfinished`, with `set`. When an orchestrator subagent ran
  the plan, copy them from its final message.

### Finish

- **Give finishing the record's `base`** at its Step 3.
- The menu is your human partner's. Show it as `finishing` words it, and
  wait.

### Close

- **After the menu is answered,** whatever the answer, invoke the skill
  with `close <effort id> <phase id>`. The close handles each answer, a
  discard included, and hands over. Do not start another phase in this
  session.
