# Resuming From an Existing Ledger

Part of superpowers-extended-cc:subagent-driven-development. This plan's workspace
already has a ledger at `<workspace>/progress.md`.

If the ledger's first line names your plan file, tasks with a `Task <id>:
complete` line are DONE. Do not re-dispatch them. Of the tasks without
one, dispatch every ready task, by rule 1 of
[parallel-dispatch.md](parallel-dispatch.md). A task whose plan heading holds nested part headings
(`#### Task <id>a`, …) is DONE when every part has its own `Task <part id>:
complete` line. Its parts are the tasks, and it has no line of its own.
A task that the ledger split during the build (`Task <id>: Ruling: split
into …`) is DONE when every part the ruling names has its own `Task
<part id>: complete` line. Its parts without one are dispatched the same way. A task whose last line is a fix round is mid-loop:
resume the loop at the next round. A ledger whose first line names a
different plan file — or a stray ledger at the old flat path
`.superpowers/sdd/progress.md` — is another plan's progress: leave it in
place and start your own, fresh.

A task in flight in a nested worktree, or with a
`Task <id>: approved (commits …)` line and no completion line, resumes by
rule 6 of [parallel-dispatch.md](parallel-dispatch.md).
