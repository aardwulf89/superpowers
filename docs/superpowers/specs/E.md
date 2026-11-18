# E: Rebase the fork onto pcvelz/superpowers dev

## Intent

This fork was built on obra/superpowers. Its own changes are a few skill
tweaks and one major feature, chaining-plans. Your human partner wants the
fork to sit on pcvelz/superpowers `dev` instead: a Claude Code–only fork of
obra with native task management, task hooks, user gates, model routing and
more. Every divergence pcvelz makes from obra is wanted, as is, unasked.
Our changes are then rebuilt on top, in pcvelz's terms.

The biggest part of the move is the task setup. Spec D gave chaining-plans
and both executors one task schema of our own. pcvelz already does tasks
natively, with hooks that judge them. Our tasks must become pcvelz tasks,
not a second system next to them.

## Goals

- `main` is pcvelz `dev` plus our changes, with real git ancestry, so a
  later `git merge pcvelz/dev` conflicts only on what pcvelz changed since.
- Every pcvelz divergence from obra survives.
- Every feature of ours works on the new base: reference-style ids, the
  deferred-findings round, chaining-plans with its record, finishing under
  native worktrees, and the private-fork AGENTS.md.
- Every task our skills make is either a pcvelz work task or a pcvelz step
  task (see Tasks), fully compatible with pcvelz's TaskCreate hooks.
- Every bug the walk found in pcvelz's flows is fixed (section 4a).
- Nothing is written across a worktree boundary, and the chain's durable
  state lives in git.

## Non-goals

- Changing pcvelz behavior beyond what our features need and the bug
  fixes of section 4a.
- Keeping support for the harnesses pcvelz dropped (Codex, Cursor, Gemini,
  OpenCode, Pi, Antigravity, Hermes, Muse, Kimi, Devin).
- Replaying our 79 commits. The port is by feature, from the final state.
- Contributing anything to pcvelz or obra.
- Migrating chain records from before the port (`.superpowers/chain`).
  As in spec A, an effort in flight finishes on the plugin it started
  on, or is created again. *My call:* this repo has none.

## Anti-goals

- **A hybrid.** chaining-plans, or any skill of ours, making or naming
  tasks differently from how pcvelz does them. Also, any mechanism of ours
  running beside a pcvelz mechanism for the same job.
- A task of ours that pcvelz's TaskCreate hooks block or misjudge, with
  model routing or the at-end commit strategy switched on.
- Losing any of our specs or plans, so that `next-spec-id` reissues a
  letter.

## Constraints

- **Baseline:** `pcvelz/dev` at `f189a6f` (version `7.1.2-dev`). pcvelz
  `dev` merged upstream v7.0.2 (`22f0b46`), which is exactly where our
  `main` branched. So the forks share history.
- **What to port:** `git diff 22f0b46 archive/obra-main` (today's `main`,
  `9235d5e`) is the full set of our changes.
- **Hooks that must accept our tasks:** `hooks/pre-taskcreate-model-tier`
  and `hooks/pre-taskcreate-commit-strategy`, both registered by default.
  Every blocker chain we set must also pass the optional
  `hooks/examples/pre-task-blockedby-enforce.sh`: no task goes in_progress
  while a blocker is open.
- **Claude Code's worktree isolation** (tested on 2.1.327; see Worktrees)
  refuses compound git commands, `cd` to the main checkout before git, and
  `git -C <main checkout>` from inside an `EnterWorktree` worktree.
- Zero third-party dependencies, as in both forks. `record.py` uses only
  the Python standard library.

## Approaches

### Git mechanics

- **A. A new `main` built from pcvelz `dev` (picked).** Branch from
  `pcvelz/dev`, port our changes as new commits, then that branch becomes
  `main`. The old `main` is kept as branch and tag `archive/obra-main`.
  This gives the clearest history (`git log pcvelz/dev..main` is exactly
  ours) and clean future syncs. It costs one force-push of `main`, and
  possibly removing and re-adding the marketplace in Claude Code.
- B. On a branch off `main`, merge `pcvelz/dev` keeping only pcvelz's
  tree, then port. No force-push, but our 79 old commits stay in the
  history as "ours" even though their content was thrown away.
- Ruled out: a plain replacement commit with no pcvelz parent (every
  pcvelz sync would conflict from v7.0.2 again). Also ruled out:
  replaying our commits (most conflicts would be in text we're replacing
  anyway).

### Chain tasks

- **Keep chaining-plans' own tasks, refitted to pcvelz (picked).**
- Drop them, and let the chain record alone show progress. That loses
  what D fixed, a whole phase showing as one task.

### Task titles

- **Split along pcvelz's own line (picked).** Work tasks keep
  `<id>: <name>`. Step tasks become `<name> (<id>)`.
- D's single `<id>: <name>` for everything. Rejected: the hooks read
  `A3: Design` as a plan task (see Tasks).
- Id first without the colon (`A3 Design`). Rejected: only the missing
  colon keeps it from matching the hooks' title pattern.

### Execution method in a chain

- **Always subagent-driven-development, with the chain answering pcvelz's
  handoff (picked).** The run stays unattended up to the merge menu.
- Let writing-plans ask, as in pcvelz. Every phase would stop once at
  Plan.
- Ruled out: running `executing-plans` inside the session again. That
  would undo one of pcvelz's divergences.

### The chain's record

- **E1–E3 (picked):** the build's results are committed on the phase
  branch, phase state comes from positive evidence, and the record is
  committed on `base`. Nothing is written across the worktree boundary.
- Keep the record outside git, written from the worktree by a script run
  by its path. Rejected: it works only through a gap in the harness's
  isolation, and keeps carried items on one machine.
- Record `branch` before entering the worktree. Rejected: it breaks the
  invariant that a recorded branch means a build started. A session that
  dies before the first commit would read as merged.

### The final-commit exemption

- **Widen the prefix to one word with no spaces, ending in a colon
  (picked).** The anchor stays.
- Our exact id grammar in the hook. Rejected: a second copy of
  `next-spec-id`'s grammar that drifts.
- Leave the commit task without an id. Rejected: its task title would no
  longer match its `### Task K3.9:` heading, so the executors' match by id
  breaks.

## Design

### 1. Repo mechanics

1. Create branch `rebase/pcvelz` from `pcvelz/dev` (`f189a6f`), in a
   worktree.
2. Port each part below as its own commit or commits, through the normal
   plan and review flow.
3. When the branch is done and its tests pass: tag and push the old
   `main` as `archive/obra-main`, then point `main` at the new branch.
   Force-push `main` only after your human partner confirms it at that
   moment.
4. From then on, `git merge pcvelz/dev` (or a pcvelz release) brings
   upstream in. The `upstream` (obra) remote stays fetch-only, for
   reference. Nothing merges from it directly.

### 2. Identity

- The plugin's name is pcvelz's: `superpowers-extended-cc`. Every
  `superpowers:<skill>` reference in our ported text becomes
  `superpowers-extended-cc:<skill>`.
- The marketplace's name stays ours: `superpowers-aardwulf`
  (`.claude-plugin/marketplace.json`), so it doesn't clash with pcvelz's
  `superpowers-extended-cc-marketplace`. *My call:* the marketplace path
  references (`~/.claude/plugins/marketplaces/superpowers-extended-cc-marketplace/`:
  15 in README.md, 5 in commands/onboard.md, 1 in
  hooks/examples/stop-wait-guard.sh, 1 in skills/writing-plans/SKILL.md)
  become `…/superpowers-aardwulf/`, so they point at the installed copy.
- **Version:** `<pcvelz version>+aardwulf.<N>`, starting at
  `7.1.2-dev+aardwulf.1`. Always bump with pcvelz's
  `scripts/bump-version.sh` (files from `.version-bump.json`).
- **AGENTS.md:** pcvelz's file with our private-fork block on top (from
  the archived `main`). Its versioning rule is restated for the new base:
  bump N with every push that changes plugin content; reset it to 1 when
  merging a new pcvelz release; obra arrives only through pcvelz.
  pcvelz's `CLAUDE.md` (which points to AGENTS.md) stays.
- **README.md:** chaining-plans gets a row in pcvelz's skill table.

### 3. Ids, across the whole plugin

Spec A's reference-style ids (spec letter `K`, plan/phase `K3`, task
`K3.4`, split parts `K3.4a`, commits `feat(K3.4): …`) replace pcvelz's
dated file names and `Task N` everywhere pcvelz's text names a spec, a
plan, a task or a tasks file. One naming scheme in the whole plugin.

- **brainstorming:** specs go to `docs/superpowers/specs/<letter>.md`,
  with a letter from `scripts/next-spec-id`, as on the archived `main`.
- **writing-plans:** the Ids section, `# <plan id>: …` first lines,
  `### Task <plan id>.<n>:` headings, and commit subjects, as on the
  archived `main`. Its Native Task Integration and Task Persistence
  sections use ids: subject `K3.4: [Component Name]`, and tasks file
  `docs/superpowers/plans/K3.md.tasks.json`, with ids in its `subject`
  fields.
- **Executors:** the archived `main`'s Ids paragraph, ledger line forms,
  the split rule (section 4), and `task-start`/`task-done`/`task-brief` taking
  ids, all applied to pcvelz's text.
- **Everything else that shows one:** requesting-code-review examples,
  SDD prompts and references, specifying-gates, implementer-prompt,
  `skills/shared/task-format-reference.md` examples, README and
  `docs/*.md` examples.
- **`hooks/session-start`'s at-end notice** uses ids too: its ledger form
  becomes `Task <id>: complete (working tree, at-end strategy, review
  clean)`, and the plan's single commit carries the plan id
  (`feat(K3): …`).
- **The tier hook needs no change.** Our work tasks always carry the
  metadata block, which is the hook's explicit signal, so its title
  patterns never decide them.
- **The commit-strategy hook's final-commit exemption is widened, and
  stays anchored.** Today it exempts a subject that is exactly `Commit the
  full implementation`, optionally after `Task N:`. That's a fence (pcvelz
  `6ef5c27`, `docs/workflow-config-flow.md`): the task can only be
  recognized by its title, and the anchor stops a per-task commit from
  hiding behind a longer title. The only prefix allowed is the plan's own
  task number. Our id is that number, so the prefix becomes "`Task N:` or
  one word with no spaces, ending in a colon":

  ```
  ^[ ]*(task[ ]*[0-9]+[.:][ ]*|[^[:space:]:]+:[ ]*)?commit the full implementation[.!]?[ ]*$
  ```

  The hook must not encode the id grammar. Ids are unpadded, have no
  fixed width, and go to any depth (`K3.10`, `AA12.10`, `K3.4a1b`), and
  their one definition is `next-spec-id`. New cases in
  `test-taskcreate-commit-strategy-hook.sh`: `K3.9:`, `K3.10:`,
  `AA12.10:`, `K3.4a1:`, `M1.1:` and a bare `3:` are exempt. Test 17's
  cases, and a prefix with a space (`Step 2: Commit the full
  implementation`), stay blocked.
- pcvelz's hook tests keep their `Task 3:` fixtures, because a plan
  without ids still produces them, and gain id-shaped cases.

### 4. Tasks

**pcvelz's model.** pcvelz has two kinds of task:

- **Work tasks** are units of a plan. Brainstorming starts them
  (`Implement X`). writing-plans refines them, and each gets **Goal /
  Files / Acceptance Criteria / Verify** and a closing `json:metadata`
  block (with `modelTier` when routing is on). They are persisted to
  `<plan>.md.tasks.json`, and the executors read the block and resume from
  that file.
- **Step tasks** are one per checklist item of a skill (using-superpowers,
  diagnosing-superpowers, writing-skills). They are plain and never
  persisted.

**What the hooks judge.** A TaskCreate counts as a work task if it has
the metadata block, the template headings, or a subject that matches
`^(Task|Phase|Gate|Step|Milestone) ?[0-9][0-9.]*:` or
`^[A-Za-z]{0,6}[0-9][0-9A-Za-z.]*([/+][0-9A-Za-z.]+)*:`. With routing on:

- a work task without a metadata block is blocked once a plan skill has
  run in the session;
- a metadata block without a valid `modelTier` is blocked;
- an Agent dispatch must match the combined tiers of every in_progress
  task.

**Why D's titles fail.** `A3: Design` and `K3a: Build` match the second
pattern. Without a block they are blocked: every chained phase runs
writing-plans. With a block they need a tier, and an in_progress
`A3: Build` with a tier loosens which model every implementer may be
dispatched on. (`K: Draft the phases` passed only because `K` has no
digit.)

**Three rules.** pcvelz implies these without writing them down. This
port states them, and every skill of ours and every fix below follows
them.

1. **One signal.** A task is a work task if and only if it carries the
   `json:metadata` block. Skills use that signal, as the hooks do, never a
   title pattern. The patterns are a heuristic that is wrong both ways
   (`v2: bump deps` and `IPv6: fix parsing` read as work tasks, while a
   block-less `Implement lexer` doesn't). Step tasks never carry the block
   or the template headings, and their titles start with a fixed English
   step name, so no pattern can match them, whatever the id looks like.
2. **Ownership.** A skill makes, changes and finishes only its own tasks.
3. **Session scope.** Native tasks live for one session (they are stored
   under `~/.claude/tasks/<session id>/`). Anything that has to outlive
   the session goes in a file owned by the same skill: `.tasks.json` for
   work tasks, the chain record for the chain.

**The tasks.**

| Task | Kind | Title | Made and finished by | Outlives the session in |
|---|---|---|---|---|
| Plan tasks | work | `K3.4: Add retry` | writing-plans makes them, refining brainstorming's design-time tasks; the executor finishes them | `K3.md.tasks.json` |
| Create's steps | step | `Draft the phases (K)`, `Find the open intent questions (K)`, `Run one sitting (K)`, `Write it down (K)`, `Hand over (K)` | Create | nothing; the record carries the effort |
| Missed actions | step | `Missed close (A2)`, `Missed git ops (A2)` | Resume step 3 | nothing |
| Stages | step | `Intent round (A3)`, `Design (A3)`, `Plan (A3)`, `Build (A3)`, `Finish (A3)`, `Close (A3)` | Resume step 6 | nothing; Resume rebuilds them from the record every session |

Nothing else of ours makes tasks:

- **The executors make no step tasks**, as in pcvelz. D's
  `Final whole-branch review`, `Deferred-findings round` and `Finish`
  tasks, the reuse of `Finish`, and every link between the chain's tasks
  and the plan's tasks are dropped. In a chain, `Build (A3)` covers the
  final review and the deferred-findings round, and `Finish (A3)` is
  Resume's.
- **Close makes none.** The caller's `Close (A3)` or `Missed close (A2)`
  covers it.
- **Brainstorming's design-time tasks** are brainstorming's (rule 2). In
  a session that ends in Create, nothing of ours touches them, and they
  end with the session that Create's hand-over asks to clear (rule 3).

**Splits.** A part has its own dispatch, review gate, commits and
completion line, so it is a unit of work, and a unit of work is a work
task. One rule covers every split, whenever it happens:

- **Each part gets a full work task:** its own Goal, Files, Acceptance
  Criteria and Verify, a metadata block with a tier, and an entry in
  `.tasks.json`. Hooks and dispatch treat it like any plan task. SDD
  builds each implementer prompt from the work task (TaskGet), so a part
  is dispatched with its own scope, not the whole task's.
- **A task that already exists stays.** It gets each part as a blocker,
  is never dispatched, and completes when its last part does: `K3.4` still
  names the whole. It can't be deleted: the blocker hook clears a blocker
  only when its status is `completed`, and `TaskUpdate` can add blockers
  but not remove them, so a deleted parent would block everything that
  waits on it.
- **A split made before any task exists** (nested `#### Task K3.4a`
  headings in a plan whose tasks aren't made yet) makes tasks for the
  parts only.
- **During the build the plan is not edited**, as on the archived `main`.
  The ledger holds the split ruling. The parts' text lives in their tasks
  and in `.tasks.json`, which is where pcvelz already keeps task text the
  plan doesn't have (`specifying-gates` writes there too).
- In order: the first part takes the parent's blockers, and each part is
  blocked by the one before.

**Blockers and status**, on step tasks, as in D:
- Create's steps are each blocked by the one before.
- `Missed git ops` is blocked by its phase's `Missed close`.
- Stages are each blocked by the one before. The first stage is blocked by
  every missed-action task.
- A step task goes in_progress when its step starts, and completed when
  its "Done when" holds.
- Every chain must complete in order under the blocker hook. For example,
  `Build (A3)` completes when the executor's lists are copied into
  `closing`, which Resume already does before finishing starts.
- `activeForm` on stage tasks: "Designing A3", "Building A3", …
- A Scope Check split (K3 → K3a) retitles every stage task not yet
  completed, and its `activeForm`: `Build (K3)` → `Build (K3a)`.

**Resume after a cut-off:** SDD's Step 0 (section 4a) restores the plan's
tasks from `.tasks.json`, or else from the plan, and the ledger marks what
is done. D's ledger filter goes.

**Every leaf, walked.** Each place a task is made, read or changed in the
flow, and what this design does there:

| # | Leaf | Result |
|---|---|---|
| 1 | using-superpowers makes a step task per checklist item of any skill | pcvelz's; plain step tasks |
| 2 | brainstorming makes `Implement X` work tasks | pcvelz's; writing-plans in the same session refines them |
| 3 | writing-plans' first step: "if tasks exist, enhance them" | Fixed (4a): only existing work tasks |
| 4 | writing-plans makes `K3.n:` work tasks and `.tasks.json` | pcvelz's, with ids |
| 5 | Create's step tasks, retitled if the letter changes | Create's |
| 6 | Work tasks left in Create's session | Untouched; they end with the session |
| 7 | Resume's missed-action and stage tasks | Resume's |
| 8 | Plan stage: writing-plans sees the stage tasks | Covered by #3's fix |
| 9 | Build: SDD makes a task per plan task | Fixed (4a): SDD gets executing-plans' Step 0, so no duplicates |
| 10 | Dispatch hooks during Build | Step tasks carry no tier or pin, and SDD marks the work task in progress after `Build (A3)` |
| 11 | A split at any time | The split rule above |
| 12 | The executor's closing steps | No tasks, as in pcvelz |
| 13 | Resume after a cut-off | Step 0 restores the tasks; the ledger marks what is done |
| 14 | `.tasks.json` inside a worktree | Fixed (4a): committed with the plan, and the executor commits its changes |
| 15 | Close; a Scope Check split's retitles | The chain's own |
| 16 | Optional hooks: blockers, user gates, wait guard | Our chains complete in order; step tasks are never gates; the wait guard acts only in executing-plans sessions |
| 17 | Optional `pre-commit-check-tasks` | Blocks every commit while any task is in progress, which conflicts with pcvelz's own executing-plans as well. Left as is, an opt-in example |

### 4a. Fixes to pcvelz

Every bug the walk found goes in, including the ones that pcvelz's own
flows hit. Each fix applies the three rules.

1. **writing-plans enhances only existing work tasks.** Its first step
   says "if tasks exist, enhance them", but doesn't say which, so it
   would also enhance step tasks: pcvelz's own checklist tasks, and in a
   chain, Resume's stage tasks. It enhances only tasks with the metadata
   block (rule 1) and leaves every other task alone (rule 2).
2. **SDD gets executing-plans' Step 0.** SDD says "`TaskCreate` a task
   per plan task", unconditionally. In the session that ran writing-plans
   (pcvelz's own "Subagent-Driven (this session)" path, and every chained
   phase), that duplicates every task. On a resume it recreates done
   tasks as pending. SDD takes executing-plans' order: TaskList first,
   then `.tasks.json`, then build the tasks from the plan, with the
   ledger marking what is done. Both executors then follow one rule. In
   both, "the tasks match the plan" compares work tasks only.
3. **`.tasks.json` works inside a worktree.** writing-plans leaves the
   file untracked in the main checkout, and the executors rewrite it after
   every status change. Tested on 2.1.327:
   - inside an `EnterWorktree` session, Edit and Write to the main
     checkout are refused;
   - `git worktree remove` refuses a worktree with an untracked or
     modified file.

   So the file either can't be updated or blocks the cleanup. The fix:
   - the file is committed with the plan, since writing-plans made both;
   - updates go to the working tree's own copy;
   - before deleting its workspace, the executor commits the file if it
     changed (with at-end commits, the single final commit includes it);
   - the same goes for `dispatching-parallel-agents` and
     `specifying-gates`, which also rewrite it.
4. **The blocker hook clears a deleted blocker.**
   `hooks/examples/pre-task-blockedby-enforce.sh` counts a blocker as
   cleared only when it is `completed`. Yet its own message tells the
   agent to mark an obsolete blocker `cancelled` (not a native status)
   and retry, which it would then refuse. The fix: `deleted` also clears
   a blocker, and the message says `deleted`. The split rule (section 4)
   never deletes a parent, so this doesn't change it.
5. **executing-plans re-enters an existing worktree with the harness
   tool.** Its Verify Workspace step says "cd into it". Under isolation a
   `cd` is reset, and pcvelz's using-git-worktrees prefers the native
   tool. It uses `EnterWorktree` with the worktree's `path` where the
   harness has it, as Resume's cut-off path does.
6. **The commit-strategy exemption** takes an id prefix (section 3).

### 5. The deferred-findings round

This is ported into both of pcvelz's executors as on the archived `main`:

- `references/deferred-findings.md` for each executor;
- the flow becomes final review → deferred-findings round → delete the
  workspace → finishing;
- minors are ledgered for the round, not reported as "Deferred minors";
- the final message has "Rulings I made" and "Unfinished", each line
  starting with its id.

pcvelz has no counterpart, so this is a pure addition, written into
pcvelz's text.

With `commitStrategy: at-end` on, the final review's fixes and the round's
fixes are committed exactly as pcvelz's own final-review fix pass commits
them. At-end governs plan tasks, which is all pcvelz's gate checks, so no
rule of ours is added. *My call.*

### 6. chaining-plans, the record and next-spec-id

None of chaining-plans' files are fixed text. They were reviewed top
down against pcvelz and the worktree tests, under one principle:
**durable state lives in git, and is written from where the writer
stands.** A worktree writes only its own files, and the main checkout
writes only `base`. Today's chaining-plans breaks that in three ways: the
record lives outside git, in one machine's `.superpowers/chain`; it is
written from inside the worktree, through a harness gap (a script run by
its path may write to the main checkout, while Edit and Write may not);
and phase state is inferred backwards from the record ("a missing branch
means merged").

**Ported as they are,** with the namespace change, ids and section 4's
task rules: `SKILL.md`, Create, Resume's settle/pick/stages, Close's
re-plan and partner-item handling, the missed git ops, `next-spec-id`.
These were reviewed and kept. The intent/technical split and the one
sitting are the core idea, and nothing in pcvelz overlaps them. The
stages and settle-then-pick are one rule per state. The partner-item
rules hold the effort's intent. Every branch of the missed git ops
answers a real case.

**E1. The build's results travel with the build.** Between the
executor's final message and finishing, while still in the worktree, the
chain writes the final message's "Rulings I made" and "Unfinished" to
`docs/superpowers/plans/<phase id>.build.json` with the Write tool, and
commits it on the phase branch (`docs(K3): build results`). The file
belongs to the chain, and the executors don't change. Close reads it with
`git show <ref>:<path>`: from the branch while it isn't merged, from
`base` once it is. The file replaces the record write of
`closing.rulings` and `closing.unfinished` at the end of Build. It still
guards against context loss, because it's on disk before finishing
starts. The Design and Plan stages log their rulings to the record as
today, since they run on `base`.

**E2. Phase state from positive evidence.** The branch name is fixed:
`worktree-<phase id>` from `EnterWorktree`, or `<phase id>` when built
in place. So the record no longer stores `branch`, and no write happens
mid-build. `phase-state` reads, by the first rule that fits:

| Evidence | State |
|---|---|
| `status` is `dropped` | `dropped` |
| a workspace for the phase's plan exists in any worktree (`git worktree list`, then each one's `.superpowers/sdd/*/plan-path`), or in the main checkout | `cut-off` |
| `<phase id>.build.json` on `base` | merged: `done` if `closing.replan` is set, else `close-missed` |
| `<phase id>.build.json` on the phase branch, not on `base` | not merged: `closed-unmerged` if `closing.replan` is set, else `finished-unclosed` |
| the phase branch exists with commits of its own | `anomaly`: report the branch, its commits and its worktree, and stop |
| otherwise | `not-started` |

- **Merge styles:** a file's presence in `base`'s tree is the same for a
  merge, a fast-forward, a squash or a rebase. The "missing branch means
  merged" rule and the `gh pr view` fallback go.
- **A discard:** a discarded branch's file never reaches `base`, so the
  phase reads `not-started`, and Close's discard step that resets
  `branch` goes. The partner items in `closing` are kept as today.
- **The anomaly** can only follow a manual change, because the file is
  committed before the executor's workspace is deleted. It replaces
  Build's leftover-branch checks with the same stop.
- **Close's range of the phase's commits** is the commit that added the
  plan to the commit that brought `<phase id>.build.json` into the ref
  (`git log --format=%H -1 -- <path>` on that ref), along the ancestry
  path. For a squash, that is the one squash commit. This replaces the
  four-case search for the branch's merge.
- **Resume step 2's "on `base`" check** loses its case for "a branch
  whose `branch` is still null": there is no such case any more.

**E3. The record is committed.** It moves to
`docs/superpowers/efforts/<effort id>.json`, committed on `base`. After
E1 and E2, every record write happens in the main checkout on `base`,
and almost every one already comes with a docs commit (Create's Phases
commit, an Intent round's answers, Design, Plan, Close, an end round's
answers). The record rides in those commits. A write without a docs
commit (a ruling logged as a stage ends) is committed by itself
(`docs(K3): record`), so the tree stays clean for Resume step 2.
- `record.py` finds records under `docs/superpowers/efforts/` of the
  main checkout. `chain-dir` goes, `open-efforts` and `carried` read that
  directory, and `.superpowers/chain` is no longer used.
- The last message's warning that carried items "live only in this
  machine's record" goes. They are in the repo.
- Value files stay under `.superpowers/tmp/` of the working tree,
  git-ignored.
- `record.py` still runs git read-only. Committing is the chain's job,
  done as the references say.

**The execution method (your human partner's ruling).** pcvelz's
writing-plans ends in a hard-gated three-option handoff. Two of the
options open a separate session, and pcvelz's `executing-plans` runs
only in a separate session. So in a chained session the Plan stage
answers the handoff itself with pcvelz's own default, Subagent-Driven
(this session), logged as a ruling, and Build always runs
`subagent-driven-development`. A chain never picks a Parallel Session. A
session nearly out of context stops as a chain already stops, and the
next session resumes. `executing-plans` is not widened again. pcvelz's
handoff hook only checks the shape of a handoff question that is asked,
so skipping the question doesn't trip it. The standing-approval line in
`SKILL.md` is reworded for pcvelz's handoff.

**The Plan stage** commits `<phase id>.md.tasks.json` with the plan
(fix 3), and its "Done when" requires both.

### 7. Worktrees

Tested on Claude Code 2.1.327 with your human partner's own settings
(auto mode). Every refusal came from the harness worktree isolation:

- pcvelz's (upstream's) finishing Step 2 capture block is refused ("names
  git in a form too complex to verify…").
- `cd <main> && git merge` and `git -C <main> merge` are refused. A lone
  `cd` is reset, so the next `git merge` silently merges the branch into
  itself.
- `ExitWorktree remove` after a local merge is refused unless given
  `discard_changes: true` (it counts commits since creation, not whether
  they reached main). After leaving, it is a no-op. A re-entered worktree
  can't be removed by it.
- Only one order works: `ExitWorktree` keep → merge from the main checkout
  → `git worktree remove <path>` → `git branch -d`.

Design:

- **finishing-a-development-branch** keeps the archived `main`'s three
  changes: separate plain `git rev-parse` calls in Step 2, leaving with
  `ExitWorktree` keep before the merge, and removing the
  `.claude/worktrees/` worktree this session entered and left.
- **using-git-worktrees Step 4** (pcvelz) is narrowed so the two skills
  give one rule. `ExitWorktree` remove stays the way to throw away a
  worktree whose work is discarded (after the confirmation finishing
  requires). For a branch merged locally, it points to finishing's
  order.
- **A stale lock** (tested on 2.1.327). A session that dies without
  `ExitWorktree` leaves its lock on the worktree, naming its dead process.
  Re-entering by path doesn't take the lock over, `ExitWorktree` keep
  doesn't release it, and `git worktree remove` then refuses even a clean,
  merged worktree. Resume's cut-off path hits this. So in finishing's
  cleanup (and Resume's PR cleanup), when removal is refused because of a
  lock: read the process id in the lock's reason (`git worktree list
  --porcelain`), check it with a plain `ps -p <pid>`. If it is dead, run
  `git worktree unlock <path>` and remove again. If it is alive, another
  session still has the worktree open: stop and report, and never unlock
  it. `git worktree unlock` was not refused by the isolation or by auto
  mode.
- *My call:* finishing's discard option uses that same `ExitWorktree`
  remove (with `discard_changes: true`, after the typed confirmation)
  in place of leave-then-remove, since it removes the worktree and the
  branch in one step. A re-entered worktree (a cut-off phase) can't be
  removed by it ("not the owner"), so there the discard leaves with
  keep, then removes as the merge path does, the lock rule included. The
  PR option and Resume's PR cleanup stay as on the archived `main`.

### 8. Our specs and plans

`docs/superpowers/specs/` and `docs/superpowers/plans/` come over whole
from the archived `main`, including this spec. pcvelz has no
`docs/superpowers/`, so nothing conflicts. `next-spec-id` must issue `F`
next on the new branch.

### 9. Tests

- **Ported:** `tests/chaining-plans/`, `tests/next-spec-id/`,
  `tests/reference-ids/`, `tests/native-worktrees/`, the
  `test-chaining-plans-*.sh` and `test-sdd-workspace.sh` changes in
  `tests/claude-code/`, and `tests/sdd-helper-paths/`. They're adapted to
  pcvelz's `test-helpers.sh` and `run-skill-tests.sh`, and to E1–E3: the
  record under `docs/superpowers/efforts/`, no `chain-dir`, no `branch`
  key.
- **`record.py phase-state`:** a case for every row of E2's table,
  each in real git repos. The merged case covers a merge commit, a
  fast-forward, a squash and a rebase. The others cover a discarded
  branch, an anomaly branch, and a workspace in a linked worktree and in
  the main checkout.
- **`tests/task-list/test-task-list-text.sh`** is rewritten for
  section 4. Every title the skills prescribe is a work-task id or a
  `<name> (<id>)` step title. No executor text makes a step task. Close
  makes none.
- **New: a hook-compatibility test.**
  - It feeds every TaskCreate shape our skills prescribe (each step
    title, an id-titled work task with and without a tier, a split
    part) to both TaskCreate hooks, with a routing file and
    `commitStrategy: at-end` present, and a transcript where a plan skill
    has run. Step tasks must pass. Work tasks must be judged exactly like
    pcvelz's `Task N:` tasks.
  - It feeds our blocker chains, the split rule's included, to
    `pre-task-blockedby-enforce.sh` in completion order, and they must
    all pass.
- **The fixes to pcvelz:**
  - the commit-strategy hook's new exemption cases (section 3);
  - the blocker hook clearing a `deleted` blocker, while a `pending` or
    `in_progress` one still blocks;
  - text tests that writing-plans enhances only tasks with the metadata
    block, and that SDD has Step 0.
- **Finishing's lock rule:** a text test that it checks the lock's
  process before any unlock, and never runs `remove --force` or `-f -f`.
- pcvelz's existing suites still pass.

### Order of the port

One plan, in this order:

1. Identity
2. Ids
3. Tasks and the fixes to pcvelz
4. The deferred-findings round
5. chaining-plans with E1–E3, the record and `next-spec-id`
6. Worktrees
7. The specs and plans history

Then the tests, then the switch of `main`.

## Calls I made (check these)

- The marketplace path references point at `superpowers-aardwulf`.
- Finishing's discard option uses `ExitWorktree` remove, except in a
  re-entered worktree.
- The `upstream` remote stays, fetch-only.
- Under at-end, the final fixes and the deferred-findings round commit as
  pcvelz's fix pass does.
- E1's file name, `<phase id>.build.json`, and E3's path,
  `docs/superpowers/efforts/<effort id>.json`.
- A record write with no docs commit of its own is committed by itself.

## Left to the builder

- The exact wording in each file, in the style of the archived `main`'s
  text.
- Where each rule sits in pcvelz's files.
- How a split parent's entry reads in `.tasks.json`. It stays, and
  completes with its last part.
- Which pcvelz tests need id-shaped cases added.
- `record.py`'s internal restructuring for E2 and E3. Its commands keep
  their contracts: one plain command per call, atomic writes, refusals
  that change nothing.
