# SDD Deferred-Findings Round Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deferred-findings round to SDD that completes every finding the run deferred, working off the ledger, after the whole-branch review's fix wave.

**Architecture:** One new reference file, `references/deferred-findings.md`, assembled from SDD's existing sentences, plus three edits to upstream lines that say or imply the whole-branch review is the last step: two in `references/final-review.md`, one in the `SKILL.md` flowchart. No other upstream file changes.

**Tech Stack:** Markdown skill references; bash tests under `tests/`.

**Spec:** `docs/superpowers/specs/2026-11-10-sdd-deferred-findings-round-design.md`

## Global Constraints

- Upstream edits are exactly the three in Task 1 Steps 4-6, and nothing else in those files changes.
- No changes to ledger line formats, reviewer prompts, `fix-loop.md`, or any `SKILL.md` text outside the process flowchart.
- No improvised wording: `deferred-findings.md` is the exact text in Task 1 Step 3. Every sentence there is copied from `final-review.md`, `fix-loop.md`, or `SKILL.md` with only nouns adjusted, except the lines marked NEW in the source table.
- Prose calls the existing step "the final whole-branch review" (upstream's own phrase); upstream file names are unchanged.

## Review Focus

- A ledger holding a `parked — … — Ruling: <why the code stands>` line: the fixer must leave it closed, not reopen it.
- A ledger with nothing open: the fixer reports none and makes no commits; no re-review is dispatched and the round is ledgered as such.
- A fix that needs a decision only the human partner can make: it is reported open with the question, not guessed at, and lands under "Unfinished".
- New breakage the round's fix introduces that the re-review flags: it is listed under "Unfinished", since there is no second round.
- The re-review template requires `[BRIEF_FILE]` and this round has no task brief: the plan file stands in for it.

Each line is pinned by a sentence in Task 1 Step 3's text and checked by Step 1's check script.

---

### Task 1: Deferred-findings round

**Files:**
- Create: `skills/subagent-driven-development/references/deferred-findings.md`
- Modify: `skills/subagent-driven-development/references/final-review.md:29-31,44`
- Modify: `skills/subagent-driven-development/SKILL.md:79-97` (process flowchart)
- Modify: `docs/superpowers/specs/2026-11-10-sdd-deferred-findings-round-design.md` (status line)
- Test: `tests/sdd-helper-paths/test-sdd-helper-paths.sh`, `tests/skill-layout/test-no-dev-files-in-skills.sh`, `tests/skill-size/test-skill-size.sh`

**Interfaces:**
- Consumes: the ledger at `<workspace>/progress.md`; `re-review-prompt.md`; `scripts/review-package`.
- Produces: the ledger line `Deferred findings: round 1/1 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)` and the final-message heading "Unfinished".

- [ ] **Step 1: Write the check**

Save as `/tmp/check-deferred-findings.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
f=skills/subagent-driven-development/references/deferred-findings.md
fl() { tr -s '[:space:]' ' ' < "$1"; }
test -f "$f"
fl "$f" | grep -qF 'Part of superpowers:subagent-driven-development.'
fl "$f" | grep -qF 'Dispatch on the most capable available model (see SKILL.md'
fl "$f" | grep -qF 'Never fix findings yourself in the controller session'
fl "$f" | grep -qF 'whose ruling says the code stands'
fl "$f" | grep -qF 'the plan file as the brief'
fl "$f" | grep -qF 'Unfinished'
fl "$f" | grep -qF 'Deferred findings: round 1/1'
fl "$f" | grep -qF 'ordered them; it did not close them'
r=skills/subagent-driven-development/references/final-review.md
k=skills/subagent-driven-development/SKILL.md
fl "$r" | grep -qF 'There is no second fix wave — residual findings go to the deferred-findings round: read references/deferred-findings.md and run it before you finish.'
! fl "$r" | grep -qF 'surface to your human partner when finishing-a-development-branch'
fl "$r" | grep -qF 'When the deferred-findings round is done and its fixes are merged, delete'
! grep -qF 'When the final whole-branch review is clean' "$r"
test "$(git diff --numstat main -- "$r" | cut -f1-2)" = "3	3"
grep -qF '"Deferred-findings round: read references/deferred-findings.md" [shape=box];' "$k"
grep -qF '"Final review and finish: read references/final-review.md" -> "Deferred-findings round: read references/deferred-findings.md";' "$k"
grep -qF '"Deferred-findings round: read references/deferred-findings.md" -> "Deferred-findings round done: delete this plan'"'"'s workspace";' "$k"
! grep -qF 'Final review clean: delete' "$k"
test -z "$(git diff main -- "$k" | grep '^[-+][^-+]' | grep -v -e 'Deferred-findings round' -e 'Final review clean: delete')"
test -z "$(git diff --name-only main -- skills | grep -v -e references/final-review.md -e references/deferred-findings.md -e subagent-driven-development/SKILL.md)"
echo PASS
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash /tmp/check-deferred-findings.sh`
Expected: exits non-zero at `test -f` (file missing).

- [ ] **Step 3: Create `references/deferred-findings.md` with exactly this text**

````markdown
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
````

Source of each paragraph (for the reviewer):

| Paragraph | Source |
|---|---|
| Opening line | `final-review.md` line 3 shape ("Part of superpowers:subagent-driven-development. <precondition>.") |
| "Every finding the run deferred…" | NEW (spec: the round runs off the ledger; triage sentence covers the triage wording left in `fix-loop.md` and `final-review.md`) |
| "Dispatch ONE fix subagent…not one fixer per finding." | `final-review.md` fix-wave sentence, "complete findings list" → "ledger" |
| "Dispatch on the most capable available model…" | `final-review.md` verbatim |
| Report-file path and contract | `SKILL.md` "Report file" bullet |
| "read the entire ledger…the question." | NEW (spec: fixer infers open findings; reviewer-wrong rulings stay closed; owner decisions not guessed) |
| "The fixer fixes, re-runs…all three are present." | `fix-loop.md` "Every round" paragraph, "re-dispatching" → "dispatching" |
| "If the fixer found nothing open…" | NEW (Review Focus: empty ledger) |
| "Then run exactly one scoped re-review…" | `final-review.md` re-review sentence; findings list and brief clause NEW |
| "The re-reviewer verdicts…fix diff only." | `fix-loop.md` verbatim |
| "**After the round,** append to the ledger:" + line | `fix-loop.md` "After each round" line shape |
| "Never fix findings yourself…" | `fix-loop.md` verbatim |
| "There is no second round. Only the four things…" | `final-review.md` ("no second fix wave"; stop sentence verbatim) |
| "Unfinished" sentence and "The list is exhaustive…" | NEW heading; exhaustiveness sentence from `final-review.md` Finish |

- [ ] **Step 4: Point the fix-wave paragraph at the round (`final-review.md:29-31`)**

Replace `There is no second fix wave —` / `residual load-bearing findings surface to your human partner when` / `finishing-a-development-branch presents the options.` with these three lines, keeping the paragraph's wrap:

```
plan (top of SKILL.md) stop you here. There is no second fix wave —
residual findings go to the deferred-findings round: read
references/deferred-findings.md and run it before you finish.
```

- [ ] **Step 5: Retarget the workspace deletion (`final-review.md:44`)**

Replace `When the final whole-branch review is clean and its fixes are merged,` with `When the deferred-findings round is done and its fixes are merged,`. Lines 45-47 are unchanged.

- [ ] **Step 6: Add the round to the `SKILL.md` process flowchart**

- After the `"Final review and finish: read references/final-review.md" [shape=box];` line, add `    "Deferred-findings round: read references/deferred-findings.md" [shape=box];`
- Rename `Final review clean: delete this plan's workspace` to `Deferred-findings round done: delete this plan's workspace` everywhere it appears (its node line and the two edges).
- Change the edge from `"Final review and finish: read references/final-review.md"` so it points to `"Deferred-findings round: read references/deferred-findings.md"`, and add the edge `    "Deferred-findings round: read references/deferred-findings.md" -> "Deferred-findings round done: delete this plan's workspace";` directly after it.

- [ ] **Step 7: Set the spec's status**

In the spec, change `Status: awaiting owner approval.` to `Status: approved by the owner.`

- [ ] **Step 8: Run the checks and the repo tests**

Run: `bash /tmp/check-deferred-findings.sh && bash tests/sdd-helper-paths/test-sdd-helper-paths.sh && bash tests/skill-layout/test-no-dev-files-in-skills.sh && bash tests/skill-size/test-skill-size.sh`
Expected: `PASS`, then `PASS: all 15 relative helper references…`, `PASS: no skill ships…`, `PASS: every SKILL.md is under 20000 bytes`.

- [ ] **Step 9: Commit**

```bash
git add skills/subagent-driven-development/references/deferred-findings.md skills/subagent-driven-development/references/final-review.md skills/subagent-driven-development/SKILL.md docs/superpowers/specs/2026-11-10-sdd-deferred-findings-round-design.md
git commit -m "feat(sdd): deferred-findings round after the final whole-branch review"
```
