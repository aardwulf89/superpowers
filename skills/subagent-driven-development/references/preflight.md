# The Pre-flight Scan

Part of superpowers-extended-cc:subagent-driven-development. Run it once, before
dispatching the first task.

Before dispatching the first task, scan the plan once for conflicts, writing down
what you checked as you check it:

- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a
  defect (a test that asserts nothing, verbatim duplication of a logic block)

The scan's output is a table, not a verdict. One row for every pair of tasks
that share a file or an interface: the two tasks, what one produces against
what the other consumes, and what you found. One row for every task: whether
its own text agrees with itself — the tests it specifies against the code it
specifies, the files it creates against the files it later touches. "The scan
is clean" without those rows is not a scan you ran.

Every scan ends with the dependency ruling, even a clean one. Two tasks
are dependent if:

- one consumes an interface that the other produces;
- one needs a generated or git-ignored artifact that the other makes;
- both take from an allocator (anything that hands out numbers or names
  across branches);
- anything about the pair is unclear.

Rule from the table's rows and the plan's text, and give only these
reasons. A shared file is never a reason: each parallel writer works in its
own worktree. One worktree is never a reason. Record
`<plan id>: Ruling: dependencies — <which tasks depend on which> — <why> — cost if wrong: <what breaks>`.
When two or more tasks are ready, read
[parallel-dispatch.md](parallel-dispatch.md) before you dispatch.

Write the table to the ledger. Rule on everything you find before execution
begins — each finding against the plan text that mandates it — and record
each ruling in the ledger. If the scan is clean, proceed without comment.
Rule on each conflict it surfaces. The spec is the binding authority. The
plan is its argument. Record the ruling beside its row as
`<plan id>: Ruling: …` (a row spans tasks, so it takes the plan's id), and
dispatch the first task. The review loop remains the net for conflicts that only emerge from
implementation.
