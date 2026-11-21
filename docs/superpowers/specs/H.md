# H: The plan carries the dependencies

## Intent

Independent tasks of a plan run in parallel every time. Today the plan
records its tasks as a chain, and the controller has to rediscover the
real dependencies at run time. That judgment has failed in run after run.
This spec puts the dependencies in the plan, where the author knows them,
and leaves the controller one way to dispatch, with no judgment about
whether to run in parallel.

## Evidence

- D19 (Lairage session `a927a065-d9ea-49a3-b0b3-9879bfe7ba79`; issue #3 on
  aardwulf89/superpowers; diagnosis in
  `~/.superpowers/diagnosing-superpowers/a927a065-d9ea-49a3-b0b3-9879bfe7ba79/report.md`):
  the plan's task file records D19.1 ← D19.2 ← D19.3 ← D19.4, a straight
  chain. The true dependencies were D19.2 and D19.3 on D19.1, and D19.4 on
  nothing. The pre-flight found the right links, then ruled "run serially
  … cost if wrong: none, serial is safe". D19.2–D19.4 ran in series for
  11m00s. The longest of the three took 4m06s.
- D14 (Lairage): the pre-flight ruled every task serial for "shared files"
  and "one worktree". Text fixes `864afcc` and `2843c71` banned those
  reasons, and D19 found a new one.
- Correct dependencies in the plan were not enough while the controller
  kept a go/no-go step. D17's plan says "Four independent changes" and has
  no edges; the run went serial because parallel commits "contend on CPU".
  D16b2e's plan says ".1 and .2 are independent"; the run went serial
  anyway (Lairage `D17.build.json`, `D16b2e.build.json`).
- Each implementer that runs in parallel already gets its own worktree, so
  conflicting writes are never a reason to wait. A task waits only when it
  uses something another task produces.

## Decisions (the partner's)

- **The plan carries the dependencies.** `writing-plans` sets a task's
  `blockedBy` only to tasks it cannot be completed without (definition
  below). Plan order alone is never a dependency.
- **One way to dispatch.** Every implementer works in its own nested
  worktree, always. The controller dispatches every task whose `blockedBy`
  tasks are complete, and each newly unblocked task as soon as its last
  blocker completes.
- **No run-time dependency ruling, and no script.** The pre-flight keeps
  its conflict scan and drops the dependency ruling.

## Goals

- A plan whose tasks are independent runs them at the same time, with no
  decision by the controller.
- No skill text tells the controller to serialize on doubt, on a shared
  file, or on one working tree.

## Non-goals

- No change to the per-task loop, the final review, its fix wave, or the
  deferred-findings round.
- No change to how a task in a nested worktree is reviewed, integrated,
  gated or resumed (`parallel-dispatch.md` rules 2–6 and 8–10).
- No change to chaining-plans.

## Anti-goals

- Two writers in one working tree.
- A controller that waits on a task the plan does not block it on, or
  runs a task before its blockers are complete.
- A script, hook or ledger ceremony between agent dispatches.

## Approaches considered

1. **Text fixes to the run-time ruling.** Tried three times (D14, the D14
   dry run, and the text D19 ran under). Each banned the last bad reason,
   and the next run found another one.
2. **A readiness script over structured ledger links.** Rejected by the
   partner: it polices the controller's wording, and a script run between
   agents is ceremony on every dispatch.
3. **Dependencies in the plan, one way to dispatch (chosen).** The author
   of the plan knows which task uses what. With a worktree per
   implementer, nothing else needs ruling.

## Design

### `skills/writing-plans/SKILL.md`

- "Setting Dependencies" defines a hard dependency (approved by
  the partner):

  > Task B waits for task A only when B cannot be completed in a tree
  > without A's commits: B's steps, tests or Verify step need code, files
  > or behaviour that A adds, changes or removes. Plan order, a shared
  > file, and text that only repeats what the plan already fixes are never
  > reasons. A task with no such need has no `blockedBy`.

  For D19 this gives D19.2 and D19.3 blocked by D19.1, and D19.4 blocked by
  nothing.
- The `.tasks.json` example shows a task with no `blockedBy` after one
  that has it, so the example no longer reads as a chain.

### `skills/subagent-driven-development/SKILL.md`

- Dispatch: every implementer gets its own nested worktree, by
  `parallel-dispatch.md`. Dispatch every task whose `blockedBy` tasks are
  complete. When a task completes, dispatch every task it unblocks.
- The trigger "When the pre-flight's ruling shows two or more tasks ready,
  read parallel-dispatch.md" goes. Read `parallel-dispatch.md` before the
  first dispatch.
- Bounded Parallel Dispatch: "Run implementers concurrently ONLY when
  neither depends on the other in the pre-flight's dependency ruling"
  becomes "neither blocks the other in the plan". "Never two writers on one
  file" becomes "Never two writers in one working tree". "When overlap is
  uncertain, serialize" goes.
- The Setup node of the process graph drops "and dependency ruling".

### `references/preflight.md`

- The dependency ruling section goes: the list of dependency reasons, the
  "shared file" and "one worktree" lines, the `Ruling: dependencies` form,
  and the pointer to `parallel-dispatch.md`. The conflict scan and its
  rulings stay.

### `references/parallel-dispatch.md`

- The opening says this file is how every implementer is dispatched, not a
  mode for two or more ready tasks.
- Rule 1: a task is ready when every task in its `blockedBy` has its
  completion line. Plan order picks which ready task goes first. The plan's
  `blockedBy` is no longer described as a chain to leave alone.
- Rule 4: a rebase stop makes the stopped task wait for the other to land,
  then rebase and get a scoped re-review, as now. It no longer "rules the
  pair dependent" in a pre-flight sense.
- Rule 7: under `commitStrategy: "at-end"`, implementers do not commit, so
  the run dispatches one task at a time in the phase worktree, in plan
  order, honoring `blockedBy`. The `pre-task-blockedby-enforce` hook is no
  longer a reason to run sequentially: with true dependencies, its refusals
  match the dispatch rule.

### `references/resuming.md`

- No change beyond any wording that names the dependency ruling.

### Tests

- `tests/parallel-dispatch/test-skill-text.sh` and
  `test-reference-text.sh`: pin the new lines. Add `lacks` checks for
  "When overlap is uncertain, serialize", "Never two writers on one file",
  "anything about the pair is unclear", and the `Ruling: dependencies`
  form in `preflight.md`.
- A text check on `writing-plans/SKILL.md` for the hard-dependency
  definition.

## Left to the builder

- Exact wording of each changed line, in the style of the file it is in.
- Whether the at-end sequential run keeps a nested worktree or uses the
  phase worktree, provided there is never more than one writer in a tree.
