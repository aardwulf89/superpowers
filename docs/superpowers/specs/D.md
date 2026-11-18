# D: one task schema for chained and executor runs

## Intent

A chained session on effort A made one task for a whole phase
("A3 Design → Plan → Build → Finish → Close"), and the user had to ask for
it to be split. `7.0.2+aardwulf.8` added a task-per-stage rule to Resume
§6, but the task list across chaining-plans and the two executors still
has gaps: two title styles, no blockers, no status rules, an executor task
("…Deferred-findings round and finish") that overlaps the chain's Finish
stage, and nothing for Create, Resume §3, or a Scope Check split.

Goal: every task in a chained or executor run follows one schema, is
blocked by what it really waits on, and moves through its states by a
stated rule. The task list reads as the run's real progress.

Non-goals: tasks for Resume steps 1, 2 and 4 (reads); changes to plan
headings or ledger lines; changes to `finishing-a-development-branch`.

Anti-goal: a title rule that breaks exact-title matching (the Finish
check, the split retitle).

## Approaches

Who makes the Finish task, given that the executors run "unchanged" and do
not know they are in a chain, and Resume makes its stage tasks before the
executor starts:

- **A. Check first (picked).** The executor makes `<plan id>: Finish` only
  when no task of that title exists. Otherwise it adds its last task as a
  blocker of the existing one. Works because the plan id is the phase id.
- B. The executor always makes it; Resume makes none. The task lands after
  `<phase id>: Close` in the list, and Resume's Finish duties have no task.
- C. The executor never makes it. A run outside chaining-plans tracks
  nothing for the merge menu.

Title schema: `<id>: <name>` (picked) over a kind word on every title
(`A3 Stage: Design`, `A3 Task 1: Add lexer`), which lengthens every line to
say what the id already says.

## Design

### The title schema

Every task title is `<id>: <name>`.

- `<id>` is the most specific unit the task works on: the effort (`K`), the
  phase or plan (`K3`; in a chain the plan id is the phase id), or the plan
  task (`K3.2`). No "Task" word: the id shows the level. Plan headings and
  ledger lines keep `Task K3.2`.
- `<name>` is the name of what the task runs, from where it is defined: a
  plan task's name from its plan heading; a workflow step's fixed name from
  its skill. Step names stay generic so titles match exactly.

### Where tasks are made

| Where | Tasks | Blockers |
|---|---|---|
| Create | One per step, by its heading word for word: `K: Draft the phases`, `K: Find the open intent questions`, `K: Run one sitting`, `K: Write it down`, `K: Hand over`. If step 4 issues a different letter, retitle them | Each by the one before |
| Resume §3 | One per action of a row: `A2: Missed close`, `A2: Missed git ops` | `Missed git ops` by the same phase's `Missed close`. None across phases |
| Resume §6 | One per stage that runs: `A3: Intent round`, `A3: Design`, `A3: Plan`, `A3: Build`, `A3: Finish`, `A3: Close`. Skip rules as in `.8` | Each by the one before; the first by every §3 task |
| Close | None: the caller's task (`A3: Close`, `A2: Missed close`) covers it | — |
| Executors | One per plan task (`A3.1: Add lexer`), then `A3: Final whole-branch review`, `A3: Deferred-findings round`, and `A3: Finish` by the check-first rule | Each by the one before. `Finish` by `Deferred-findings round`, added with `TaskUpdate` when the task already existed |

No blocker on `A3: Build` from the executor's tasks: Build is in progress
while they run. The `Finish` link ties the two lists.

### Status and spinner

- A task goes in_progress when its step starts, and completed only when
  its "Done when" (or its section's end) holds. A step that hits a stop
  condition stays in_progress. The Intent round and Finish stay in_progress
  across the turn's end.
- `A3: Build` is completed once the executor's lists are copied into
  `closing`.
- Resume §6 stage tasks set `activeForm`: "Asking A3's intent questions",
  "Designing A3", "Planning A3", "Building A3", "Finishing A3",
  "Closing A3".

### Renames and resumes

- A Scope Check split (K3 → K3a) retitles, with `TaskUpdate`, every stage
  task not yet completed. Completed tasks keep their titles.
- On a `cut-off` resume, the executor makes tasks only for plan tasks
  with no completion line in the ledger.

### The executor's last task

"…Deferred-findings round and finish" becomes `<plan id>: Deferred-findings
round`. It ends when the final message holds "Rulings I made" and
"Unfinished". The merge menu belongs to `<plan id>: Finish`.

## Calls left to the builder

Exact wording in each file, in the STE-leaning style of the `.8` text;
where each rule sits in its file; test updates that match the new titles.
