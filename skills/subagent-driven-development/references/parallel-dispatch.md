# Parallel Dispatch

Part of superpowers-extended-cc:subagent-driven-development. Read this file
when the pre-flight's dependency ruling shows two or more tasks ready at
once. Parallel dispatch is automatic within the plan: your human partner
decided this. Run the ready tasks in parallel by the rules below.

Each task keeps its full loop: implementer, task review, fix loop and
ledger lines. These rules add only what parallel work needs.

## 1. Dependencies come from the pre-flight scan, every run

The pre-flight table has a row for every pair of tasks that share a file
or an interface. From it, rule which tasks depend on each other. Two tasks
are dependent if they have any of these:

- a shared file;
- an interface that one produces and the other consumes;
- a generated or git-ignored artifact;
- a shared allocator (anything that hands out numbers or names across
  branches);
- a glob you cannot expand;
- anything unclear.

Record the ruling in the ledger as `<plan id>: Ruling: dependencies — …`.
The plan's `blockedBy` chain stays as written. It still gives the plan
order.

## 2. One writer per tree

Never put two writers in one working tree. Give each parallel implementer
its own worktree, nested under the phase worktree:

```bash
git worktree add <phase worktree>/.superpowers/wt/<task id> -b <task id>
```

Make it from the phase worktree's HEAD.

Before the first one, run `git check-ignore` on `.superpowers/wt/`. If the
folder is not ignored, write a self-ignoring `.superpowers/wt/.gitignore`
(as `sdd-workspace` does for `.superpowers/sdd/`).

Nothing else writes in a tree that has a writer, you included.
While any nested worktree exists, every writer works in a nested worktree.
The phase worktree takes only integration commits.

When all tasks are integrated and their worktrees are removed, the run
continues as before: final review, its fix wave, the deferred-findings
round and the task-status commit.

## 3. Reviewers read the task's own worktree

A reviewer reads the task's worktree at the task's commit. It never reads
the phase worktree. Build the review package from the task's worktree.

## 4. The controller integrates; the ledger keeps its forms

Write the per-task ledger lines as they happen, in their usual forms:
dispatch, fix rounds, minors, parked findings and rulings. The dispatch
line also names the task's nested worktree.

When a task's review is approved (or parked with rulings at the cap),
bring it into the phase branch:

1. Run `git -C <nested> rebase <phase branch>`.
2. In the phase worktree, run `git merge --ff-only <task branch>`.
3. Remove the nested worktree and delete the task branch.
4. Only then write the task's completion line, with the integrated commit
   range.

Only the controller writes the ledger.

## 5. Gates on the merged head

A fast-forward runs no hooks. Never claim the merged head is clean without
a gate run. Run the project's gates on it before the final review. If a
gate fails, give the failure to the final review as a finding. Its fix wave
fixes it, unchanged.

## 6. Resume

If a task's dispatch line names a nested worktree that still exists, the
task is in flight. Resume its implementer there, or re-dispatch into the
same worktree. Never run `git worktree add` for it again.

## 7. When parallel dispatch does not run

Run sequentially, and note the reason in the ledger, in these cases:

- `commitStrategy: "at-end"`. Implementers do not commit, so there is
  nothing to rebase.
- The opt-in `pre-task-blockedby-enforce` hook is installed. It refuses
  `in_progress` on a task whose `blockedBy` is incomplete. To disable it
  at runtime, set `SUPERPOWERS_BLOCKEDBY_GUARD=0`.

## 8. A unique temporary folder per writer

Some tools lock the whole machine (golangci-lint holds
`/tmp/golangci-lint.lock`). Concurrent commits then fail. In each
dispatch, tell the implementer to run its commits with `TMPDIR` set to a
folder of its own.

## 9. Ask first, beyond the plan

One nested worktree per plan task is within the plan. It needs no
question.

These need your human partner's approval:

- splitting a task for parallelism;
- tasks or worktrees beyond the plan's tasks;
- any other parallel work the plan does not hold.

A question about them states the counts: tasks, worktrees and agents at
once. Splits for other reasons (a BLOCKED task that is too large, see
handling-reports.md) are unchanged.

Do not stop the run to ask. Run the plan as written. Put the proposal,
with its counts, in your final message under "Unfinished".

## 10. Known hazards

Each hazard comes from a real run.

- Pre-commit's stash in a shared tree: it runs `git checkout -- .` on every
  tracked file, and it silently lost 82 of 88 edits of a second writer.
- Fast-forwards and cherry-picks: they skip hooks, so a merged tree can fail
  gates that each task passed.
- Git-ignored tools: a new worktree does not have them.
- Linters that walk git-ignored folders: scratch code in the phase worktree
  fails a commit while nested worktrees exist.
- `git worktree add` outside the session worktree: the harness refuses it.
- Compound git commands: the harness refuses them in an isolated worktree.
  Run one plain command per call, and use `git -C <dir> …` where a
  directory is needed.
- Recorded lessons that were never tested: one false lesson (that an
  isolated agent worktree "branches from origin main") spread through an
  effort record. Check a lesson before you copy it into a dispatch.
