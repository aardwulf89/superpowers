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

## Non-goals

- Changing pcvelz behavior that our features don't touch.
- Keeping support for the harnesses pcvelz dropped (Codex, Cursor, Gemini,
  OpenCode, Pi, Antigravity, Hermes, Muse, Kimi, Devin).
- Replaying our 79 commits. The port is by feature, from the final state.
- Contributing anything to pcvelz or obra.

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
  build-time split rule, and `task-start`/`task-done`/`task-brief` taking
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

**The unified setup.**

| Task | Kind | Title | Made by | Persisted in |
|---|---|---|---|---|
| Plan tasks | work | `K3.4: Add retry` | writing-plans, refining brainstorming's design-time tasks (pcvelz's TaskList-first step) | `K3.md.tasks.json` |
| Create's steps | step | `Draft the phases (K)`, `Find the open intent questions (K)`, `Run one sitting (K)`, `Write it down (K)`, `Hand over (K)` | chaining-plans Create | nothing (the chain record carries the effort) |
| Missed actions | step | `Missed close (A2)`, `Missed git ops (A2)` | Resume step 3 | nothing |
| Stages | step | `Intent round (A3)`, `Design (A3)`, `Plan (A3)`, `Build (A3)`, `Finish (A3)`, `Close (A3)` | Resume step 6 | nothing (Resume rebuilds them from the record every session) |
| Executor's closing steps | step | `Final whole-branch review (K3)`, `Deferred-findings round (K3)`, `Finish (K3)` | each executor, as its checklist | nothing |

Rules:

- **Never depend on the title patterns.** They are a heuristic, wrong
  both ways (`v2: bump deps` and `IPv6: fix parsing` read as work tasks,
  while a block-less `Implement lexer` doesn't). Our tasks are told apart
  only by the explicit signal: work tasks always carry the metadata block,
  and step tasks never carry it or the template headings. A step task's
  title always starts with its fixed English step name, so no title
  pattern can match it, whatever its id looks like.
- **Work tasks are pcvelz's exactly:** template, metadata block, tier,
  user-gate tagging, `.tasks.json` sync. The only difference is the id in
  the subject. A plan task split in the plan (`#### Task K3.4a`) gets a
  work task per part and none for the parent. A task split during the
  build (an executor's split ruling) gets its parts made as work tasks,
  in the same format, added to `.tasks.json`.
- **Step tasks are plain:** no metadata block, no template headings, no
  tier, never in `.tasks.json`, and the name comes first, so no subject
  pattern matches.
- **No duplicates:** before making a step task, a skill checks
  `TaskList` and reuses a task with the same title (pcvelz's writing-plans
  already does this for work tasks). In a chain, the executor finds
  Resume's `Finish (A3)` (the plan id is the phase id) and adds
  `Deferred-findings round (A3)` to its blockers. This replaces D's
  check-first rule.
- **Blockers:** as in D, in the new titles. Create's steps are each
  blocked by the one before. `Missed git ops` is blocked by the same
  phase's `Missed close`. Stages are each blocked by the one before, the
  first by every missed-action task. The executor's closing steps:
  `Final whole-branch review` is blocked by the last work task, and each
  step after by the one before.
- **Status:** as in D. A step task goes in_progress when its step starts,
  and completed when its "Done when" holds. Every chain must be
  completable in order under the blockedBy hook. For example,
  `Build (A3)` completes when the executor's lists are copied into
  `closing`, which Resume already does before finishing starts.
- **activeForm** on stage tasks, as in D: "Designing A3", "Building A3", …
- **Renames:** a Scope Check split (K3 → K3a) retitles every stage task
  not yet completed, and its activeForm: `Build (K3)` → `Build (K3a)`.
- **Resume after a cut-off:** pcvelz's restore from `.tasks.json`
  replaces D's ledger filter for work tasks. The executor remakes only
  the closing steps not yet done.
- **Close makes no tasks:** the caller's `Close (A3)` or `Missed close
  (A2)` covers it.
- **Brainstorming's design-time tasks in a chained spec:** pcvelz's
  brainstorming makes `Implement X` work tasks for the whole spec. Once
  Create has split the spec into phases, it deletes those tasks
  (`TaskUpdate`, status `deleted`). Each phase's writing-plans makes its
  own. *My call.*

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

- Port `skills/chaining-plans/` (SKILL.md, references, `scripts/record.py`)
  and `skills/brainstorming/scripts/next-spec-id`, with the namespace
  change and the task rules of section 4 replacing D's task text.
- Executor and stage references follow pcvelz's skill text where they
  quote it.
- **The execution method (your human partner's ruling).** pcvelz's
  writing-plans ends in a hard-gated three-option handoff. Two of the
  options open a separate session, and pcvelz's `executing-plans` runs
  only in a separate session. So in a chained session the Plan stage
  answers the handoff itself with pcvelz's own default,
  Subagent-Driven (this session), logged as a ruling, and Build always
  runs `subagent-driven-development`. A chain never picks a Parallel
  Session. A session nearly out of context stops as a chain already
  stops, and the next session resumes. `executing-plans` is not widened
  again. pcvelz's handoff hook only checks the shape of a handoff
  question that is asked, so skipping the question doesn't trip it.
- *My call:* the Plan stage's "Done when" also requires
  `K3.md.tasks.json` to be committed with the plan. The worktree starts
  from `base`, and the executor's cross-session resume reads that file
  from inside the worktree.

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
- *My call:* finishing's discard option uses that same `ExitWorktree`
  remove (with `discard_changes: true`, after the typed confirmation)
  in place of leave-then-remove, since it removes the worktree and the
  branch in one step. The PR option and Resume's PR cleanup stay as on
  the archived `main`.

### 8. Our specs and plans

`docs/superpowers/specs/` and `docs/superpowers/plans/` come over whole
from the archived `main`, including this spec. pcvelz has no
`docs/superpowers/`, so nothing conflicts. `next-spec-id` must issue `F`
next on the new branch.

### 9. Tests

- Port our tests: `tests/chaining-plans/`, `tests/next-spec-id/`,
  `tests/reference-ids/`, `tests/native-worktrees/`, the
  `test-chaining-plans-*.sh` and `test-sdd-workspace.sh` changes in
  `tests/claude-code/`, and `tests/sdd-helper-paths/`. Adapt them to
  pcvelz's `test-helpers.sh` and `run-skill-tests.sh`.
- `tests/task-list/test-task-list-text.sh` is rewritten for section 4:
  every title the skills prescribe is either a work-task id or a
  `<name> (<id>)` step title.
- **New: a hook-compatibility test.** It feeds every TaskCreate shape our
  skills prescribe (each step title, an id-titled work task with and
  without a tier) to both TaskCreate hooks, with a routing file and
  `commitStrategy: at-end` present, and a transcript where a plan skill
  has run. Step tasks must pass. Work tasks must be judged exactly like
  pcvelz's `Task N:` tasks. It also feeds our blocker chains to
  `pre-task-blockedby-enforce.sh` in completion order, and they must all
  pass.
- The commit-strategy hook's new exemption cases (section 3).
- pcvelz's existing suites still pass.

### Order of the port

1. Identity
2. Ids
3. Tasks
4. Deferred-findings round
5. chaining-plans with record and next-spec-id
6. Worktrees
7. Specs and plans history

Then the tests, then the switch of `main`.

## Calls I made (check these)

- The marketplace path references point at `superpowers-aardwulf`.
- The Plan stage commits `K3.md.tasks.json` with the plan.
- Finishing's discard option uses `ExitWorktree` remove.
- The `upstream` remote stays, fetch-only.
- Under at-end, the final fixes and the deferred-findings round commit as
  pcvelz's fix pass does.
- Create deletes brainstorming's design-time tasks for a chained spec.

## Left to the builder

- The exact wording in each file, in the style of the archived `main`'s
  text.
- Where each rule sits in pcvelz's files.
- Whether `.tasks.json` status syncs during a build are committed with
  each task's commit or left for finishing, provided finishing's
  clean-tree checks still pass.
- How the parent of a split task is closed in `.tasks.json`.
- Which pcvelz tests need id-shaped cases added.
