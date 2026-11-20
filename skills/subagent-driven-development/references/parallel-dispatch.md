# Parallel Dispatch

Part of superpowers-extended-cc:subagent-driven-development. Read this file
when the pre-flight's dependency ruling shows two or more tasks ready at
once. Parallel dispatch is automatic within the plan. Your human partner
decided that ready tasks run in parallel without asking them first. Run the
ready tasks in parallel by the rules below.

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

Disjoint `files` lists are not enough. Two tasks that share no file are
still dependent if any other item above holds.

Record the ruling in the ledger as
`<plan id>: Ruling: dependencies — <which tasks depend on which> — <why> — cost if wrong: <what breaks>`.
The plan's `blockedBy` chain stays as written.

A task is ready when every task it depends on in the ruling has its
completion line (it is integrated). Its `blockedBy` entries do not hold it
back. Plan order only says which ready task to dispatch first.

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

The dispatch's `Work from:` is the nested path. Every command the
implementer runs addresses it explicitly: absolute paths and
`git -C <nested>`. A subagent's working directory resets to the phase
worktree, so the implementer never edits or runs in the phase worktree.
Tell the implementer to leave no untracked files in its worktree. They
block its removal.

Nothing else writes in a tree that has a writer, you included.
While any nested worktree exists, every writer works in a nested worktree.
The phase worktree takes only integration commits.

When all tasks are integrated and their worktrees are removed, the run
continues as before: final review, its fix wave, the deferred-findings
round and the task-status commit.

## 3. Reviewers read the task's own worktree

A reviewer reads the task's worktree at the task's commit. It never reads
the phase worktree. Build each package with:

```bash
bash <this skill's scripts>/review-package -C <nested> PLAN_FILE BASE HEAD
```

Run it by its absolute path. Do this for the task review and for every
fix-round re-review. Take BASE from `git -C <nested> rev-parse HEAD` before
the dispatch. Name the nested path in the reviewer's dispatch as the tree to
read.

## 4. The controller integrates; the ledger keeps its forms

Write the per-task ledger lines as they happen, in their usual forms:
dispatch, fix rounds, minors, parked findings and rulings. The dispatch
line also names the task's nested worktree:
`Task <id>: dispatch (<model>, base <base7>, worktree .superpowers/wt/<task id>)`.

When a task's review is approved (or parked with rulings at the cap),
write `Task <id>: approved (commits <base7>..<head7>, review clean)` (or
`<K> parked` in place of `review clean`). Then bring it into the phase
branch:

1. Run `git -C <nested> rebase <phase branch>`. If the rebase stops, run
   `git -C <nested> rebase --abort`. Rule the pair dependent in the ledger.
   Resume the task's implementer to rebase and resolve in its own worktree,
   then run a scoped re-review before you integrate.
2. In the phase worktree, run `git merge --ff-only <task branch>`.
3. In the phase worktree, run `git worktree remove <nested>`. Then run
   `git branch -d <task id>`. If the remove refuses, the worktree still has
   modified or untracked files. List them with
   `git -C <nested> status --short`. Resume the task's implementer to
   delete its scratch files. A file that belongs to the task is unreviewed
   work: the implementer commits it, a scoped re-review runs, and you run
   steps 1-3 again. Never use `--force`.
4. Only then write the task's completion line, with the integrated commit
   range.

Only the controller writes the ledger.

## 5. Gates on the merged head

A fast-forward runs no hooks. Never claim the merged head is clean without
a gate run. The project's gates are the checks a commit runs (its commit
hooks), the test commands the plan's tasks verify with, and any gate the
project's instructions name. Run each one by hand in the phase worktree on
the merged head, before the final review. If a gate fails, give the failure
to the final review as a finding. Its fix wave fixes it, unchanged.

## 6. Resume

Read each unfinished task's ledger lines, then check its nested worktree.

- No `approved` line, and the nested worktree from its dispatch line still
  exists: the task is in flight. Resume its implementer there, or
  re-dispatch into the same worktree. Never run `git worktree add` for it
  again.
- An `approved` line and no completion line: the task is approved but not
  integrated. Run rule 4 from step 1. If the nested worktree is
  gone, steps 1-3 already ran. Run `git branch --list <task id>`. If the
  branch is listed, run `git branch -d <task id>`. Then write the
  completion line.

## 7. When parallel dispatch does not run

Run sequentially, and note the reason in the ledger, in these cases:

- `commitStrategy: "at-end"`. Implementers do not commit, so there is
  nothing to rebase.
- The opt-in `pre-task-blockedby-enforce` hook is installed. It refuses
  `in_progress` on a task whose `blockedBy` is incomplete. Your human
  partner can turn the hook off with `SUPERPOWERS_BLOCKEDBY_GUARD=0`.
  You do not.

## 8. A unique temporary folder per writer

Some tools lock the whole machine (golangci-lint holds
`/tmp/golangci-lint.lock`). Concurrent commits then fail. In each
dispatch, tell the implementer to run its commits with `TMPDIR` set to a
folder of its own.

Put the folder outside every worktree, at
`${TMPDIR:-/tmp}/sdd-<plan id>-<task id>`. Give its absolute path in the
dispatch. The implementer makes it with `mkdir -p <folder>`. It runs each
commit, and each lint or test command, as `TMPDIR=<folder> <command>`. A
folder inside a worktree shows as untracked files and blocks the removal
of that worktree. In the trial, `TMPDIR` on tmpfs worked; one test failed
with `TMPDIR` on btrfs.

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
- Turning off the `pre-task-blockedby-enforce` hook: only your human
  partner does it (`SUPERPOWERS_BLOCKEDBY_GUARD=0`).
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
