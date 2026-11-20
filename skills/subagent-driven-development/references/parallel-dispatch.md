# Parallel Dispatch

Part of superpowers-extended-cc:subagent-driven-development. When the
pre-flight's dependency ruling shows two or more tasks ready at once, read
this file and run them in parallel without asking. Each task keeps its full
loop.

## 1. Dependencies come from the pre-flight scan, every run

The pre-flight scan rules which tasks are dependent, by the list in
[preflight.md](preflight.md). A shared file is not a dependency: each writer
has its own worktree, and rule 4 handles a rebase conflict. Leave the plan's
`blockedBy` chain as written.

A task is ready when every task it depends on has its completion line.
Its `blockedBy` entries do not hold it back. Plan order picks which ready
task goes first.

## 2. One writer per tree

Never put two writers in one working tree. Give each parallel implementer
a nested worktree, made from the phase worktree's HEAD:

```bash
git worktree add <phase worktree>/.superpowers/wt/<task id> -b <task id>
```

Before the first one, run `git check-ignore` on `.superpowers/wt/`. If it
is not ignored, write a self-ignoring `.superpowers/wt/.gitignore`.

In the dispatch:

- `Work from:` is the nested path.
- Every command uses absolute paths or `git -C <nested>`. The implementer
  never edits or runs in the phase worktree.
- The implementer leaves no untracked files.

While any nested worktree exists, nothing else writes in a tree that has
a writer, you included, and the phase worktree takes only integration
commits. After the last nested worktree is removed, the run continues as
usual with the final review.

## 3. Reviewers read the task's own worktree

Build every review package, for the task review and for each re-review,
by the script's absolute path:

```bash
bash <this skill's scripts>/review-package -C <nested> PLAN_FILE BASE HEAD
```

Take BASE from `git -C <nested> rev-parse HEAD` before the dispatch. Name
the nested path in the reviewer's dispatch as the tree to read. Never send
a reviewer to the phase worktree.

## 4. The controller integrates; the ledger keeps its forms

Write the usual ledger lines as they happen. The dispatch line names the
worktree:
`Task <id>: dispatch (<model>, base <base7>, worktree .superpowers/wt/<task id>)`.

When the review is approved, or its findings are parked at the cap, write
`Task <id>: approved (commits <base7>..<head7>, review clean)` (`<K> parked`
in place of `review clean`). Then:

1. Run `git -C <nested> rebase <phase branch>`. If it stops, run
   `git -C <nested> rebase --abort` and rule the pair dependent. Resume
   the implementer to rebase and resolve in its worktree, then run a
   scoped re-review.
2. In the phase worktree, run `git merge --ff-only <task branch>`.
3. In the phase worktree, run `git worktree remove <nested>`, then
   `git branch -d <task id>`. If the remove refuses, list the files with
   `git -C <nested> status --short` and resume the implementer. It deletes
   scratch files. It commits task files, which then get a scoped re-review
   before steps 1-3 run again. Never use `--force`.
4. Write the completion line, with the integrated commit range.

Only you write the ledger.

## 5. Gates on the merged head

A fast-forward runs no hooks. Before the final review, run every gate by
hand on the merged head, in the phase worktree. The project's gates are its
commit hooks, the plan's verify commands, and any gate the project's
instructions name. A failure goes to the final review as a finding. Never
call the merged head clean without this run.

## 6. Resume

For each unfinished task:

- No `approved` line, and the nested worktree exists: the task is in
  flight. Resume its implementer there, or re-dispatch into the same
  worktree. Never run `git worktree add` for it again.
- An `approved` line and no completion line: run rule 4 from step 1. If
  the nested worktree is gone, steps 1-3 already ran. Run
  `git branch --list <task id>`. If it is listed, run
  `git branch -d <task id>`. Then write the completion line.

## 7. When parallel dispatch does not run

Run sequentially, and record the reason in the ledger, when:

- `commitStrategy` is `"at-end"`: implementers do not commit, so there is
  nothing to rebase;
- the opt-in `pre-task-blockedby-enforce` hook is installed. Your human
  partner can turn it off with `SUPERPOWERS_BLOCKEDBY_GUARD=0`. You do not.

## 8. A unique temporary folder per writer

In each dispatch, give the implementer a folder of its own, by its
absolute path, outside every worktree: `${TMPDIR:-/tmp}/sdd-<plan id>-<task id>`.
The implementer runs `mkdir -p <folder>`, then runs each commit, lint and
test command as `TMPDIR=<folder> <command>`. Machine-wide tool locks, such
as golangci-lint's, then do not fail concurrent commits.

## 9. Ask first, beyond the plan

One nested worktree per plan task needs no question. These need your human
partner's approval:

- splitting a task for parallelism;
- tasks or worktrees beyond the plan's tasks;
- any other parallel work the plan does not hold.

Do not stop the run to ask. Run the plan as written, and put the proposal
in your final message under "Unfinished", with its counts: tasks,
worktrees and agents at once. Splits for other reasons follow
handling-reports.md.

## 10. Known hazards

- Pre-commit's stash runs `git checkout -- .` and loses another writer's
  uncommitted edits in the same tree.
- Fast-forwards and cherry-picks skip hooks.
- A new worktree lacks git-ignored tools.
- Linters that walk git-ignored folders fail a commit on scratch code in
  the phase worktree while nested worktrees exist. Keep scratch code out of
  the phase worktree.
- The harness refuses `git worktree add` outside the session worktree.
- The harness refuses compound git commands in an isolated worktree. Run
  one plain command per call.
- A lesson in an effort record can be untested. Check it before you copy it
  into a dispatch.
