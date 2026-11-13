# The Deferred-Findings Round

Part of superpowers:executing-plans. The final whole-branch review's fix
pass is done.

Every `minor (deferred)` line in the ledger is still work. Sorting a
finding to Minor deferred it; it did not close it.

Fix the deferred minors yourself — you are the implementer here — in ONE
pass. Each fix is verified by TDD, not by a second reviewer: write the test
that reproduces the finding, watch it fail, make it pass, then run the
whole suite. Record each in the ledger as
`<plan id>: Final: fixed <finding> — <test name> RED→GREEN, suite <N>/<N>`,
with commit subjects that carry the plan id (`fix(<plan id>): …`). A fix
without a test that failed first is not verified; a suite that is not
green after the pass means the pass is not over. Do not dispatch a
re-review: it would re-read a diff whose covering tests already answer
"addressed" and whose suite run already answers "broke nothing".

A fix that needs a decision only your human partner can make is not
guessed at: leave that finding open, with the question.

**After the round,** append to the ledger:
`Deferred findings: round 1/1 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)`

There is no second round. Only the four things that stop a running plan
(top of SKILL.md) stop you here. Every finding the round leaves open goes
into your final message under "Unfinished", after "Rulings I made", each
starting with the id it concerns and with what was tried. The list is exhaustive: if the round left a finding
open, the list holds it.

Then continue with Finish in [SKILL.md](../SKILL.md).
