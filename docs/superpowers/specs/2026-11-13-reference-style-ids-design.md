# A: Reference-style ids for specs, phases and tasks

## Intent

When one effort runs across several plans, every plan numbers its tasks
from `Task 1`. Text from one plan outlives its session: the record's
`rulings`, `unfinished`, `learned` and `replan` lines, findings moved into
a later phase, commit subjects that Close reads back, harness todos. A
later agent reading "Task 3" cannot tell which plan, or which spec, it
means.

This is preventive. No session has gone wrong this way yet. Your human
partner wants it as cheap insurance: every reference to a spec, phase or
task must resolve to exactly one thing, from the id alone, across plans
and across specs, with nothing left to ambiguity. Ids carry no words: a
slug is one more thing that can be ambiguous, and an id doesn't need a
meaning. The scheme must be consistent, including how it looks, and
must say exactly what happens when a phase or task is split at any point.

## Goals

- One id form per level, used everywhere a spec, phase or task is named.
- Unique across the repo: no two specs, phases or tasks ever share an id.
- An id, once committed, means the same scope forever.
- An explicit rule for splitting a phase or a task, and for merging
  phases, at every point it can happen.
- The same form whether or not the plans are chained.

## Non-goals

- Renaming docs that already exist. Specs and plans written before this
  change keep their dated names. Letters start at `A` in each repo.
- Migrating efforts already in flight (see Calls).
- Ids for anything below a task (steps keep their plain numbers).

## Anti-goals

The change fails, even if it works, if:
- an id contains a word or slug;
- an id ever means two different scopes, or is reused after a drop;
- a committed id is renumbered;
- a short form and a long form of the same reference coexist (the full
  id is the only form).

## Constraints

- Private fork: edit skills directly. Your human partner said to ignore
  skill-length lint warnings (`tests/skill-size`).
- Ids must be valid in git branch names, file names on every OS
  (including case-insensitive file systems), URLs, jq strings and commit
  subjects.
- `skills/subagent-driven-development/scripts/task-brief` already parses
  `#+ Task <ID>` headings, where an ID is `[A-Za-z0-9]+(\.[A-Za-z0-9]+)*`
  with at least one digit, and a deeper heading whose ID extends the
  requested one with a letter is a sub-task kept in the parent's brief.
  The scheme keeps working with it, with one change for second-level
  split parts (see Splits and merges).
- Each skill writes its rules in its own words. The project shares
  scripts and subagent prompts across skills by relative path, never
  prose rules (see Approaches).
- Pushing this change bumps the fork version with
  `scripts/bump-version.sh` (`7.0.2+aardwulf.3`).

## The scheme

### Forms

| Level | Form | Example | Unique within |
|---|---|---|---|
| Spec | uppercase letters | `K` | the repo |
| Phase | spec + number | `K3` | its spec |
| Task | phase + `.` + number | `K3.4` | its phase |

Prior art: scripture references (John 3:16) and statute numbering
(§12(a)(1)).

**Grammar.**

```
spec    = UPPER+                  letters A–Z, skipping I and O
phase   = spec NUM part*          K3, K3a, K3a1
task    = phase "." NUM part*     K3.4, K3.4a, K3a.2
part    = lower+ | NUM            alternating after the number: 3, 3a, 3a1, 3a1b
NUM     = [1-9][0-9]*             no zero-padding
lower   = a–z, skipping i, l and o
```

Spec letters go `A, B, … H, J, … N, P, … Z, AA, AB, …`, Excel-style,
skipping I and O, so they can't be misread as 1 and 0. Split letters
skip i, l and o for the same reason. Split letters are always lowercase
and spec letters always uppercase, so no two ids differ only in case.

**Search.** `grep -w` never confuses siblings: `K3` never matches `K31`
or `K3a`, and `K3\.4` never matches `K3.41` or `K3.4a`. Because `.` is
not a word character, `grep -w K3` also matches K3's tasks (`K3.4`) and
`K3.md`. To include split parts, use a pattern: `K3[a-z0-9]*` finds a
phase, its parts and all their tasks.

### Where ids go

| Thing | Form |
|---|---|
| Spec file | `docs/superpowers/specs/K.md`, first line `# K: <Title>` |
| Phase design file | `docs/superpowers/specs/K3.md`, first line `# K3: <Title>` |
| Plan file | `docs/superpowers/plans/K3.md`, first line `# K3: <Feature Name> Implementation Plan` |
| Plan task heading | `### Task K3.4: <Component Name>` (the word `Task` stays, for `task-brief`) |
| Branch | `K3` |
| Effort record | `.superpowers/chain/K/effort.json` (the effort id is the umbrella's spec letter, which for a new spec is also its basename) |
| Phases section entry | `### K3: <Title>` |
| Record `id`, `depends_on`, `waits_on[].from`, `affects` | `K3` |
| Harness todo | `Task K3.4: <name>`; closing todos `K3: Final whole-branch review` and `K3: Deferred-findings round and finish` |
| Implementer and reviewer prompts | `Task K3.4` wherever they say `Task N` |
| Ledger lines | the existing forms, with full ids: `Task K3.4: complete …`, `Task K3.4: Ruling: …`, `Task K3.4: parked — … — Ruling: …`; a ruling about no single task (setup, execution method, the final review's fix pass) is `K3: Ruling: …`. Every ruling line still contains `Ruling:`, so the final message's collection step is unchanged |
| Final message | each "Rulings I made" and "Unfinished" line names the full id it concerns |
| SDD workspace | `.superpowers/sdd/K3/` (keyed by the plan's basename, unchanged) |
| Commit subject | the narrowest id the commit belongs to (see Commits) |

### Issuing ids

- **An id is issued when the doc that holds it is committed.** Until
  then, renumber freely: a fresh effort always reads K1…Kn in work order,
  and a fresh plan always reads K3.1…K3.n.
- **After issue, an id is never renumbered, reused, or pointed at
  another scope.** An id that was issued and later dropped or deleted
  stays retired. Its number leaves a gap.
- **Spec letters** come from one script, `next-spec-id` (below), run
  immediately before the spec is committed.
- **Phase numbers** are issued by Create, in work order. After Create,
  new phases come only from splits, which use letters, so phases never
  need a counter.
- **A spec's plans are always phases.** A spec planned without Create
  gets its first plan as `K1`, its next as `K2` (the next number no plan
  or record of that spec has used). If Create later chains the spec, the
  phases those plans implement keep those numbers, and the other phases
  take numbers not yet used, in work order. A plan Create does not link
  (one written for a waiting phase) keeps its id. If your human partner
  deletes it, the number is retired.
- **A spec that predates the scheme** (dated name, no letter) gets a
  letter once, the first time it is planned or chained, from
  `next-spec-id`. The letter is stamped into the spec's first line
  (`# K: <its existing title>`) and committed. The file keeps its name.
  From then on it is spec K like any other: its plans are K1, K2, …, and
  Create on it uses K and the effort id K.
- **A plan with no spec at all** gets a fresh letter of its own from
  `next-spec-id`, and is phase 1 of that letter. No spec file is written
  for the letter; the plan file `K1.md` holds it.
- **A plan whose headings carry no ids** (an old dated plan, one written
  by hand with `### Task 1`, one from another tool) runs as it is: the
  executors use its headings' own ids verbatim. Nothing is issued at
  execution time.
- **Task numbers** are issued in order when the plan is committed. A
  task added later to a committed plan takes the next number after the
  highest issued in that plan, and sits where it belongs in the plan's
  order. A plan rewritten for the same phase continues the numbering
  from the highest task number the phase has ever issued.

### Splits and merges

**A split appends a part, and the parent's id keeps naming the whole.**
"K2" still means K2a and K2b together. Old references to K2 stay true.

**Phase split** (Resume's Plan stage, from `writing-plans`' Scope Check,
or a close's re-plan; only for a phase whose `branch` is null, as today):
- The record replaces K2's entry with K2a, K2b, … in work order. The
  existing rules in `record.md` under `set-phases` apply, with these id
  changes:
  - **Every** part gets a suffixed id. None keeps the bare `K2`.
  - K2a takes what the first part takes today: K2's `spec` and
    `closing`. The session goes on as K2a.
  - The other phases' rules stay: a `depends_on` on K2 lists every part,
    and a `waits_on` that a part will answer gets that part as `from`.
- The Phases section replaces the K2 entry with `### K2a: …`,
  `### K2b: …`, dividing K2's words as today.
- A part that splits again alternates: K2a becomes K2a1 and K2a2.

**Task split** has three cases.
- **Before the plan is committed** (writing it, or its self-review):
  renumber freely. No split letters are needed.
- **In a committed plan** (a close's re-plan, or any later edit to the
  plan on `base`): the parent heading stays (`### Task K3.4: …`). Its
  words are divided under nested headings one level deeper
  (`#### Task K3.4a: …`, `#### Task K3.4b: …`), with nothing added that
  the re-plan doesn't call for. `task-brief K3.4` then returns the whole
  and `task-brief K3.4a` returns one part. Executors run the parts, never
  the parent on its own, and create one todo per part.
- **During the build** (the executor rules that a task must be done in
  parts; SDD's "break it into smaller pieces" in
  `references/handling-reports.md` is this case): the executor does not
  edit the plan. It logs `Task K3.4: Ruling: split into K3.4a (<what>)
  and K3.4b (<what>) — <why>`, and uses the part ids from then on in
  todos, ledger lines, commits and the final message.
  - Each part starts from the parent's brief: `task-brief` / `task-start`
    run with the parent id, and the dispatch adds the ruling's
    description of the part.
  - Each part gets its own review gate, reviewed against the part as the
    ruling describes it, not against the whole brief.
  - Each part's completion line uses its own id (`task-done` with the
    part id).
  - On resume, a parent with a split ruling is complete when every part
    the ruling names has a completion line.

A part that splits again alternates: K3.4a becomes K3.4a1 and K3.4a2.
`task-brief` today treats a deeper heading as a sub-task only when its
id grows by a letter or a dot, so `task-brief K3.4a` would drop nested
`K3.4a1`/`K3.4a2` parts. Change it so that a growth by a digit also
counts when the requested id ends in a letter (`K3.4a` → `K3.4a1`), and
still not when it ends in a digit (`K3.4` → `K3.41` stays a different
task). Add tests for both.

**Phase merge** (a close only, as today): K4 absorbs K5. The merged
phase keeps K4, the first in array order, as today. K5 leaves the
record, as today. The Phases section's K4 entry gets a line
`**Merged from:** K5`. K5 is never issued again. This is the one case
where an id's meaning widens: K4 now covers K5's scope.

**Drop:** the phase stays in the record as `dropped`, as today. Its id
is retired.

### Commits

Every commit subject carries the narrowest id it belongs to:
- a task's commits: the task id, `K3.4` or a part `K3.4a`;
- the final whole-branch review's fix pass and the deferred-findings
  round: the phase id, `K3`;
- a phase's design, plan, or Phases-section commits on `base`: the phase
  id, `K3`;
- a spec, and Create's Phases section: the spec letter, `K`.

When the repo uses conventional commits, the id is the scope:
`feat(K3.4): add retry cap`. Otherwise the subject starts with the id
and a colon: `K3.4: Add retry cap`. The `writing-plans` template's
commit step shows the conventional form.

### `next-spec-id`

A Bash script at `skills/brainstorming/scripts/next-spec-id`, run as
`bash <path>/next-spec-id`. `writing-plans` calls it by relative path
(`../brainstorming/scripts/next-spec-id`) for a plan that needs a fresh
letter, the way `executing-plans` calls SDD's scripts.

- It prints the next unused spec letter.
- **Used letters** are every leading letter run of a file name in
  `docs/superpowers/specs/` and `docs/superpowers/plans/` that matches
  the grammar (`K.md`, `K3.md`, `K3a.md`), plus every directory under
  `.superpowers/chain/` that is a spec letter. Dated legacy names never
  match, because they start with a digit.
- It also reads the first line of every file in the specs directory: a
  title `# K: …` marks K used, which covers lettered legacy specs.
- It reads the working tree and the `base` branch's tree
  (`git ls-tree`). A letter used in either is taken, so a worktree on a
  branch can't hand out a letter already committed on `base`. `base` is
  the repo's default branch, or an argument.
- The doc directories default as above and can be passed as arguments,
  for a project whose human partner keeps docs elsewhere.
- It is tested like `tests/chaining-plans/test-record-commands.sh`:
  empty repo gives `A`; the skipped letters; `Z` gives `AA`; legacy
  names ignored; a letter only on `base` counts; a letter only in the
  working tree counts.

## What changes, by skill

- **brainstorming:** save specs as `docs/superpowers/specs/<letter>.md`
  with `# <letter>: <Title>` as the first line, the letter from
  `next-spec-id` just before the commit. It owns the script.
- **writing-plans:** the plan's id (from chaining-plans in an effort,
  else the rules under Issuing ids); the save path; the header's first
  line; `### Task K3.4:` headings; full ids for every reference to
  another task, in this plan or another; the task-split rule; the
  conventional commit example; and a self-review check that every task
  reference is a full id that exists in this plan or a named earlier
  one. The "Type consistency" example uses full ids.
- **subagent-driven-development** and **executing-plans**, each in its
  own words: todo titles and the closing todos; `Task <full id>` in
  briefs, prompts and ledger lines; rulings and final-message lines name
  their id; commit subjects; run the parts of a split task; the
  during-the-build split rule; when the executor's setup creates a
  branch, name it after the plan's phase id. `task-start` and `task-done`
  take the full id as `TASK_NUMBER` and need no code change;
  `task-brief` gets the second-level sub-task change above. Their tests
  gain a case for `Task K3.4`, a split parent with `#### Task K3.4a`
  parts, and a second-level split. Each executor's resume rules gain the
  split-parent completion rule. Plans without ids run as they are.
- **chaining-plans:** phase ids are the spec letter plus a number;
  design and plan file names; branch names; the record example and
  `p<n>-<slug>` text in `SKILL.md`, `create.md`, `resume.md`,
  `close.md` and `record.md`; the split, merge and plans-already-written
  rules above; Close copies ids verbatim into `rulings`, `unfinished`,
  `learned` and `replan`, and names ids in moved findings. The record's
  shape (ten keys) and its commands are unchanged apart from examples.
  `tests/chaining-plans/test-record-commands.sh` fixtures move to the
  new ids.
- **requesting-code-review:** its example uses `Task B1.2` from
  `docs/superpowers/plans/B1.md`, and finds BASE by the task id.

## Approaches

1. **One shared definition file, local rules in each skill, one script.**
   This keeps one source of truth, but no skill in the project shares
   prose rules this way, only scripts and subagent prompts.
2. **Inline everywhere:** every skill carries the full rules. Six copies
   of the split rules would drift apart, which is the ambiguity this
   change exists to remove.
3. **A script for everything** (`ids` to issue and check). Task ids
   live in plan prose the agent writes anyway, so most of the tool would
   repeat what the agent writes, and it is a lot of code for a naming
   rule.
4. **Each skill owns the level it issues (chosen).** brainstorming owns
   spec letters and the script. chaining-plans owns phase ids, with the
   phase split and merge rules in `record.md` where they live today.
   writing-plans owns task ids and the task-split rule. Both executors
   restate the task-split rule in their own words, like
   `deferred-findings.md`. Every skill that names ids keeps a one-line
   local rule for the forms it writes. This matches how the project
   already shares conventions. Your human partner picked it.

The id scheme itself was chosen over two others:
- **Prefixed counters `S12-P3-T4`, with tombstones and fresh numbers on
  split:** sound, but long, and after a split the ids no longer follow
  work order.
- **Hash ids, as Beads (`bd-a1b2`) uses:** collision-proof across
  branches, but you can't tell the plan from the id.

## Calls made (yours to check)

- **Ids are fixed when committed,** and renumbered freely before.
- **Files are named by id only;** the title goes on the first line.
- **Every plan is a phase,** chained or not. A plan with no lettered
  spec gets a letter of its own.
- **Spec letters skip I and O, and split letters skip i, l and o.**
- **Task headings keep the word `Task`** (`### Task K3.4:`) so
  `task-brief` keeps working. This differs from the `### K3.4:` shown
  earlier in conversation.
- **Commit subjects:** the id is the conventional-commit scope. In this
  repo, that replaces area scopes like `chaining-plans` for planned
  work.
- **Mid-build task splits** are ledger rulings and don't edit the plan.
  Parts share the parent's brief, get their own review gates, and the
  parent is complete when all its parts are.
- **Ruling lines keep their existing forms** with full ids, so the
  collection step that looks for `Ruling:` still works.
- **A pre-scheme spec gets a letter once,** stamped into its first line,
  the first time it is planned or chained.
- **Plans without ids** run as they are. Nothing is issued at execution.
- **`task-brief` changes** for second-level split parts.
- **Efforts in flight** when this lands are not migrated or supported:
  finish them before updating the plugin. This repo has none.
- **This change uses the scheme itself** (your human partner agreed).
  This doc keeps its dated name, as a pre-scheme spec, and is stamped
  spec `A` in its first line. Its plan is `docs/superpowers/plans/A1.md`
  with tasks `Task A1.1…`, and commits use `feat(A1.3): …`. The scheme
  is applied by hand, since the installed skills don't know it yet.

## Left to the builder

- The wording of each skill's local rules, in that skill's voice.
- `next-spec-id`'s internals and its argument forms.
- The order of edits and how they're split into tasks.
