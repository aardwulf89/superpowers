# The Deferred-Findings Round

Part of superpowers-extended-cc:subagent-driven-development. The final
whole-branch review's fix wave and its scoped re-review are done.

Every finding that the run deferred is still open work:

- Minor findings;
- out-of-scope observations;
- findings parked at the cap;
- the residuals of the final whole-branch review.

The ledger holds them. If the final whole-branch review triaged deferred
findings, it ordered them. It did not close them.

Dispatch ONE fix subagent with the ledger, not one fixer per finding. Use
the most capable available model (SKILL.md § Model Selection). The
dispatch carries:

- the ledger path;
- the plan path;
- the workspace's report files, for detail;
- a report-file path (`<workspace>/deferred-findings-report.md`), with
  the report contract;
- these instructions:
  1. Read the whole ledger. A finding is open if no later line shows it
     fixed. A parked finding whose ruling says the code stands is not
     open.
  2. List each open finding in the report file.
  3. Fix the open findings. Commit subjects carry the plan id
     (`fix(<plan id>): …`).
  4. If a fix needs a decision that only your human partner can make, do
     not guess. Report that finding open, with the question.
  5. Re-run the tests that cover the amended code.
  6. Append the fix report to the same report file, and return the short
     contract.

If the fixer found nothing open and made no commits, skip the re-review.
Else, check that the fix report holds the covering tests, the command it
ran and the output. Then run exactly 1 scoped re-review of the round, with
[re-review-prompt.md](../re-review-prompt.md):

- Make its package with `bash scripts/review-package PLAN_FILE FIX_BASE HEAD`,
  over the fix range of the round. Run the script by its absolute path,
  from the working tree you execute in.
- Give the fixer's list of open findings as the findings list, and the
  plan file as the brief.

The re-reviewer gives each finding a verdict: ADDRESSED or NOT ADDRESSED.
It flags new breakage in the fix diff only.

**After the round,** append to the ledger:
`Deferred findings: round 1/1 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)`

Never fix findings yourself in the controller session. Your context stays
clean for coordination, and a controller fix skips review.

There is no second round. Only the 4 things that stop a running plan (top
of SKILL.md) stop you here.

Put every finding that the re-review leaves NOT ADDRESSED, and any new
breakage it flags, in your final message under "Unfinished", after
"Rulings I made".

Start each line with the id it concerns: the task id, or the plan id for
a branch-wide finding. Say what was tried. The list is exhaustive: if the
round left a finding open, the list holds it.

Then continue with Finish in [final-review.md](final-review.md).
