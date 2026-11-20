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

The dependency ruling is part of every scan, and it is recorded even when the
scan is clean. First read rule 1 of [parallel-dispatch.md](parallel-dispatch.md):
it lists what makes two tasks dependent. Then rule which tasks depend on
each other by that list, from the table's rows and the plan's text. A shared
allocator or artifact can join two tasks that share no file. Record it in the ledger as
`<plan id>: Ruling: dependencies — <which tasks depend on which> — <why> — cost if wrong: <what breaks>`.
The plan's `blockedBy` chain stays as written. A task is ready when every
task it depends on in the ruling has its completion line (it is integrated).
Its `blockedBy` entries do not hold it back.
When two or more tasks are ready at once, run them as the rest of
[parallel-dispatch.md](parallel-dispatch.md) says.

Write the table to the ledger. Rule on everything you find before execution
begins — each finding against the plan text that mandates it — and record
each ruling in the ledger. If the scan is clean, proceed without comment.
Rule on each conflict it surfaces — the spec is the binding authority, the
plan is its argument — record the ruling beside its row as
`<plan id>: Ruling: …` (a row spans tasks, so it takes the plan's id), and
dispatch the first task. The review loop remains the net for conflicts that only emerge from
implementation.
