# The Deferred-Findings Round

Part of superpowers:subagent-driven-development. The final whole-branch
review's fix wave and its scoped re-review are done.

Every finding the run deferred is still work: Minor findings, out-of-scope
observations, findings parked at the cap, and the final whole-branch
review's residuals. The ledger is the record of them. Where the final
whole-branch review triaged deferred findings, it ordered them; it did not
close them.

Dispatch ONE fix subagent with the ledger — not one fixer per finding.
Dispatch on the most capable available model (see SKILL.md's Model
Selection). The dispatch carries the ledger path, the plan path, the
workspace's report files for detail, and a report-file path
(`<workspace>/deferred-findings-report.md`) with the report contract, and
these instructions: read the entire ledger; every finding it records that
no later line shows fixed is open, except a parked finding whose ruling
says the code stands. List each open finding in the report file, then fix
them. A fix that needs a decision only your human partner can make is not
guessed at: report that finding open, with the question.

The fixer fixes, re-runs the tests covering the amended code, appends its
fix report to the same report file, and returns the short contract. Before
dispatching the reviewer, confirm the fix report contains the covering
tests, the command run, and the output; dispatch the re-review once all
three are present. If the fixer found nothing open and made no commits,
skip the re-review.

Then run exactly one scoped re-review of the round
(`bash scripts/review-package PLAN_FILE FIX_BASE HEAD` by its absolute path,
from the working tree you're executing in, over the round's fix range,
[re-review-prompt.md](../re-review-prompt.md)), with the fixer's list of
open findings as the findings list and the plan file as the brief. The
re-reviewer verdicts each finding ADDRESSED or NOT ADDRESSED and flags new
breakage in the fix diff only.

**After the round,** append to the ledger:
`Deferred findings: round 1/1 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)`

Never fix findings yourself in the controller session — your context stays
clean for coordination, and controller fixes skip review.

There is no second round. Only the four things that stop a running plan
(top of SKILL.md) stop you here. Every finding the re-review leaves NOT
ADDRESSED, and any new breakage it flags, goes into your final message
under "Unfinished", after "Rulings I made", each with what was tried. The
list is exhaustive: if the re-review left a finding open, the list holds
it.

Then continue with Finish in [final-review.md](final-review.md).
