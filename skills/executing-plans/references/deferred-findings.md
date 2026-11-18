# The Deferred-Findings Round

Part of superpowers-extended-cc:executing-plans. The final whole-branch
review's fix pass is done.

Every `minor (deferred)` line in the ledger is still open work. A finding
sorted to Minor is deferred, not closed.

Fix the deferred minors yourself, in ONE pass. You are the implementer
here. TDD verifies each fix, not a second reviewer. For each finding:

1. Write the test that reproduces the finding.
2. Watch it fail.
3. Make it pass.
4. Run the whole suite.
5. Record the fix in the ledger as
   `<plan id>: Final: fixed <finding> — <test name> RED→GREEN, suite <N>/<N>`.

Commit subjects carry the plan id (`fix(<plan id>): …`). A fix without a
test that failed first is not verified. If the suite is not green after
the pass, the pass is not over. Do not dispatch a re-review: the covering
tests already show each finding addressed, and the suite run already
shows that nothing broke.

If a fix needs a decision that only your human partner can make, do not
guess. Leave that finding open, with the question.

**After the round,** append to the ledger:
`Deferred findings: round 1/1 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)`

There is no second round. Only the 4 things that stop a running plan (top
of SKILL.md) stop you here.

Put every finding that the round leaves open in your final message under
"Unfinished", after "Rulings I made".

Start each line with the id it concerns: the task id, or the plan id for
a branch-wide finding. Say what was tried. The list is exhaustive: if the
round left a finding open, the list holds it.

Then continue with Finish in [SKILL.md](../SKILL.md).
