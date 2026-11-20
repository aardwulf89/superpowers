# F: Parallel dispatch in subagent-driven development

## Intent

Phases finish sooner. The current workflow is very slow, and chained work
(chaining-plans, with the writing-plans handoff answered automatically) is
the primary mode. Independent tasks of a plan should run at the same time,
safely, by rules the evidence supports, without the controller improvising
a method each phase.

## Evidence

A log audit of the parallel runs of effort D in a downstream Go project
(phases D12b, D15a, D15c, D15d, D15b), a wall-clock breakdown of four
phases, and a trial of concurrent commits under pre-commit:

- Improvised parallel runs saved real time (about 32 min in D15a, 55 min in
  D15d, 2 h in D15b's waves) and lost no work or findings. No session used
  §Bounded Parallel Dispatch or the line-289 ban; each improvised a
  different method (harness isolation, a shared tree, nested worktrees with
  cherry-picks, nested worktrees with rebase and fast-forward).
- Agents picked independent tasks well when given rules: 22 clean rebases
  in D15b, 7 conflict-free cherry-picks in D15d.
- What failed was missing guardrails:
  - Two writers in one tree. In the trial, pre-commit's stash
    (`git checkout -- .` on every tracked file) silently lost 82 of 88
    edits of a second agent; two commits at once in one tree
    cross-attributed files.
  - Reviewers reading the live tree while another agent wrote (D12b): wrong
    line numbers, one commit never task-reviewed.
  - A merged tree claimed clean without a gate run; fast-forwards and
    cherry-picks run no hooks (D15b, D15d).
  - golangci-lint's machine-wide lock: 6 of 9 concurrent commits failed in
    the trial, 4 failures in D15b. A unique TMPDIR per writer fixed it in
    the trial (on tmpfs; one test failed with TMPDIR on btrfs).
  - Scope growth: an approved "one more fix task" became six parallel
    worktrees; an announced cap of 4 drifted to 8 (D15b.19).
  - A false lesson spread through the effort record (an isolated agent
    worktree "branches from origin main"; it branches from the session
    worktree's HEAD).
  - Harness friction: `git worktree add` outside the session's worktree is
    refused; compound git commands are refused in an isolated worktree;
    git-ignored tools are absent from a new worktree, and linters that walk
    git-ignored folders fail on copies placed there.
- The plan's `blockedBy` is always a linear chain (writing-plans' default),
  so pcvelz's disjointness test as written never passes.
- The controller is not the bottleneck: decision gaps of 13-26 s did not
  grow with load (up to 11 agents) or context size (up to 1M tokens).

## Goals

- Independent tasks run concurrently, each writer in its own worktree.
- Every task keeps its full loop (implementer, task review, fix loop,
  ledger lines) unchanged.
- Findings, deferrals and rulings of parallel tasks reach the one ledger,
  the final review and the deferred-findings round.
- Anything beyond the plan asks the human partner first, with counts.

## Non-goals

- No change to writing-plans. The planner is told nothing about parallel
  work, so it has no reason to shape tasks to look independent.
- No change to the final whole-branch review, its fix wave, its
  re-review, or the deferred-findings round. These are integral.
- No change to chaining-plans.
- No scripts, hooks, schedulers or caps in this design. They wait until
  this version has run and produced evidence.
- No pipelining of dependent tasks. Starting task N+1 on task N's
  unreviewed commit breaks the rule "never move to the next task while the
  review has open Critical/Important issues".

## Anti-goals

- Two writers in one working tree, ever.
- A plan's shape bent toward parallelism.
- A merged tree reported clean without a gate run on it.
- Parallel work the partner did not approve: a split task, added tasks or
  added worktrees.

## Approaches considered

1. Rules only, in a new reference file (chosen). Codifies what worked and a
   guardrail for each observed failure.
2. Single controller with machinery: a dependency-graph script, a
   readiness scheduler, an integration script, a commit wrapper with a
   heavy-command semaphore, an enforcement hook. Set aside: most of its
   decisions had no evidence, and it is larger than the problem.
3. Lane orchestrators (nested orchestrator subagents per chain of tasks).
   Rejected: the controller is not the bottleneck, so delegation buys no
   wall-clock time.
4. Harness isolation per task (`Agent` `isolation: "worktree"`). Dropped:
   it depends on `worktree.baseRef: head`, its worktree stays locked by the
   live session (blocked Finish in D15a), and its agents cannot write the
   phase workspace.

## Design

### New file: `skills/subagent-driven-development/references/parallel-dispatch.md`

Parallel dispatch is automatic within the plan (the partner's decision):
whenever the pre-flight's dependency ruling shows two or more tasks ready
at once, the controller reads this file and runs them in parallel. It holds:

1. **Dependencies come from the pre-flight scan, every run.** The
   pre-flight table already has a row for every pair of tasks that share a
   file or an interface. From it, the controller rules which tasks depend
   on each other: a shared file, a produced-and-consumed interface, a
   generated or git-ignored artifact, a shared allocator (anything that
   hands out numbers or names across branches), a glob it cannot expand, or
   anything unclear means dependent. It records the ruling in the ledger as
   `<plan id>: Ruling: dependencies — …`. The plan's `blockedBy` chain
   stays as written and still gives the plan order.
2. **One writer per tree.** Each parallel implementer works in its own
   worktree nested under the phase worktree, made with
   `git worktree add <phase worktree>/.superpowers/wt/<task id> -b <task id>`
   from the phase worktree's HEAD. Before the first one, `git check-ignore`
   checks the folder; if it is not ignored, the controller writes a
   self-ignoring `.superpowers/wt/.gitignore` (as `sdd-workspace` does for
   `.superpowers/sdd/`). Nothing else writes in a tree that has a writer,
   the controller included. While any nested worktree exists, every writer
   works in a nested worktree and the phase worktree takes only integration
   commits. Once all tasks are integrated and their worktrees removed, the
   run continues exactly as today (final review, its fix wave, the
   deferred-findings round, the task-status commit).
3. **Reviewers read the task's own worktree** at the task's commit, never
   the phase worktree. The review package is built from that worktree.
4. **The controller integrates; the ledger keeps its forms.** The per-task
   loop's ledger lines (dispatch, fix rounds, minors, parked findings,
   rulings) are written as they happen, unchanged; the dispatch line also
   names the task's nested worktree. When a task's review is approved (or
   parked with rulings at the cap), the controller brings it into the phase
   branch by `git -C <nested> rebase <phase branch>`, then
   `git merge --ff-only <task branch>` in the phase worktree, then removes
   the worktree and deletes the branch, and only then writes the task's
   completion line, with the integrated commit range. Only the controller
   writes the ledger.
5. **Gates on the merged head.** Fast-forwards run no hooks. Never claim
   the merged head is clean without running the project's gates on it; run
   them before the final review. A failure there goes to the final review
   as a finding, which its unchanged fix wave fixes.
6. **Resume.** A task whose dispatch line names a nested worktree that
   still exists is in flight: resume its implementer there, or re-dispatch
   into the same worktree. Never `git worktree add` it again.
7. **When parallel dispatch does not run:** under
   `commitStrategy: "at-end"` (implementers do not commit, so there is
   nothing to rebase), and when the opt-in
   `pre-task-blockedby-enforce` hook is installed (it refuses
   `in_progress` on a task whose `blockedBy` is incomplete). Then the run is
   sequential, and the controller notes why in the ledger; the hazards list
   names `SUPERPOWERS_BLOCKEDBY_GUARD=0`.
8. **A unique temporary folder per writer**, against tool-wide locks
   (golangci-lint's `/tmp/golangci-lint.lock`): the dispatch tells the
   implementer to run its commits with `TMPDIR` set to a folder of its own.
9. **Ask first, beyond the plan.** One nested worktree per plan task is
   within the plan and needs no question. Splitting a task for
   parallelism, adding tasks or worktrees beyond the plan's tasks, or any
   other parallel work the plan does not hold needs the partner's
   approval, and the question states the counts: tasks, worktrees, agents
   at once. Splits for other reasons (a BLOCKED task too large,
   handling-reports.md) are unchanged. The controller does not stop the
   run to ask (the partner's decision): it runs the plan as written and
   puts the proposal, with its counts, in its final message under
   "Unfinished".
10. **Known hazards**, each traced to the evidence: pre-commit's stash in a
   shared tree; fast-forwards and cherry-picks skipping hooks; git-ignored
   tools missing from a new worktree; linters walking git-ignored folders
   (scratch code in the phase worktree fails a commit while nested
   worktrees exist); `git worktree add` outside the session worktree
   refused; compound git commands refused (one plain command per call);
   recorded lessons that were never tested.

### Changes to `skills/subagent-driven-development/SKILL.md`

- At the dispatch step, "Never dispatch multiple implementation subagents
  in parallel (conflicts)." becomes "Never two writers in one working tree;
  to run tasks in parallel, read
  [references/parallel-dispatch.md](references/parallel-dispatch.md)
  first."
- In §Bounded Parallel Dispatch (pcvelz's section):
  - the implementer sentence gains "each in its own worktree
    (references/parallel-dispatch.md)";
  - "neither task appears in the other's `blockedBy` chain" becomes
    "neither depends on the other in the pre-flight's dependency ruling";
  - "The sequential per-task loop above remains the default; parallelism
    is the optimization, not the baseline." is replaced by a pointer to
    the reference file, since parallel dispatch is now automatic.
  The rest of the section (read-only agents, never skip reviews, mark
  `in_progress` before dispatch for the union-of-tiers gate, serialize
  when unsure) stays as written.
- The Setup step of the process graph names the dependency ruling as part
  of the pre-flight review.

### Changes to other files of the skill

- `references/preflight.md`: the scan ends with the dependency ruling
  (item 1 above).
- `references/resuming.md`: one line pointing at item 6 for tasks in
  flight in nested worktrees.

## Calls made by the agent

- Rebase then fast-forward, in integration order (22 clean in D15b).
- Nested worktrees at `.superpowers/wt/<task id>` (as in D15b).
- The dependency ruling lives in the existing pre-flight scan and its
  ledger, not a new step.
- Per-task ledger lines are written as they happen; only the completion
  line waits for integration (so compaction mid-loop loses nothing).
- A failed gate run on the merged head becomes a finding for the final
  review, so the final stage stays unchanged.
- No parallel dispatch under `commitStrategy: "at-end"` or with the
  opt-in blockedBy hook installed; the run is sequential.
- An unignored `.superpowers/wt/` gets a self-ignoring `.gitignore`, as
  `sdd-workspace` does.
- No new stop is added to the skill's "four things stop you".

## Left to the builder

- Wording and order of the reference file, in the skill's existing voice.
- How the dispatch prompt carries the nested worktree path and `TMPDIR`.
- The version bump (`scripts/bump-version.sh`).
