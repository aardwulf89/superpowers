# Resuming From an Existing Ledger

Part of superpowers-extended-cc:subagent-driven-development. This plan's workspace
already has a ledger at `<workspace>/progress.md`.

If the ledger's first line names your plan file, tasks with a `Task <id>:
complete` line are DONE — do not re-dispatch them; resume at the first
task without one. A task whose plan heading has nested part headings
(`#### Task <id>a`, …) is DONE when every part has its own `Task <part id>:
complete` line. Its parts are the tasks, and it has no line of its own.
A task that the ledger split during the build (`Task <id>: Ruling: split
into …`) is DONE when every part the ruling names has its own `Task
<part id>: complete` line. Resume at the first part without one. A task whose last line is a fix round is mid-loop:
resume the loop at the next round. A ledger whose first line names a
different plan file — or a stray ledger at the old flat path
`.superpowers/sdd/progress.md` — is another plan's progress: leave it in
place and start your own, fresh.

A task whose dispatch line names a nested worktree that still exists is in
flight. A task with a `Task <id>: approved (commits …)` line and no
completion line is approved but not integrated. Resume both as
rule 6 of [parallel-dispatch.md](parallel-dispatch.md) says.
