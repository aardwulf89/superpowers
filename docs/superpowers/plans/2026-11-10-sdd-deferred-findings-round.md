# SDD Deferred-Findings Round Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deferred-findings round to SDD that completes every finding the run deferred, working off the ledger, after the whole-branch review's fix wave.

**Architecture:** One new reference file, `references/deferred-findings.md`, assembled from SDD's existing sentences, plus one pointer line in `references/final-review.md`. No other upstream file changes.

**Tech Stack:** Markdown skill references; bash tests under `tests/`.

**Spec:** `docs/superpowers/specs/2026-11-10-sdd-deferred-findings-round-design.md`

## Global Constraints

- The only edit to an existing upstream file is one added line (plus its separating blank line) in `skills/subagent-driven-development/references/final-review.md`, immediately before `### Finish`: `Before you finish, read references/deferred-findings.md and run it.`
- No changes to ledger line formats, reviewer prompts, `fix-loop.md`, or `SKILL.md`.
- No improvised wording: `deferred-findings.md` is the exact text in Task 1 Step 3. Every sentence there is copied from `final-review.md`, `fix-loop.md`, or `SKILL.md` with only nouns adjusted, except the lines marked NEW in the source table.
- Prose calls the existing step "the final whole-branch review" (upstream's own phrase); upstream file names are unchanged.

## Review Focus

- A ledger holding a `parked — … — Ruling: <why the code stands>` line: the fixer must leave it closed, not reopen it.
- A ledger with nothing open: the fixer reports none and makes no commits; no re-review is dispatched and the round is ledgered as such.
- A fix that needs a decision only the human partner can make: it is reported open with the question, not guessed at, and lands under "Unfinished".
- New breakage the round's fix introduces that the re-review flags: it is listed under "Unfinished", since there is no second round.
- The re-review template requires `[BRIEF_FILE]` and this round has no task brief: the plan file stands in for it.

Each line is pinned by a sentence in Task 1 Step 3's text and checked by Step 4's greps.

---

### Task 1: Deferred-findings round

**Files:**
- Create: `skills/subagent-driven-development/references/deferred-findings.md`
- Modify: `skills/subagent-driven-development/references/final-review.md` (one line before `### Finish`)
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
test -f "$f"
grep -q 'Part of superpowers:subagent-driven-development.' "$f"
grep -q 'Dispatch on the most capable available model (see SKILL.md' "$f"
grep -q 'Never fix findings yourself in the controller session' "$f"
grep -q 'whose ruling says the code stands' "$f"
grep -q 'the plan file as the brief' "$f"
grep -q 'Unfinished' "$f"
grep -q 'Deferred findings: round 1/1' "$f"
test "$(git diff --numstat main -- skills/subagent-driven-development/references/final-review.md)" = "2	0	skills/subagent-driven-development/references/final-review.md"
grep -B2 -x '### Finish' skills/subagent-driven-development/references/final-review.md | head -n1 | grep -qx 'Before you finish, read references/deferred-findings.md and run it.'
test -z "$(git diff --name-only main -- skills | grep -v -e references/final-review.md -e references/deferred-findings.md)"
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
review's residuals. The ledger is the record of them.

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
| "Every finding the run deferred…" | NEW (spec: the round runs off the ledger) |
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

- [ ] **Step 4: Insert the pointer line in `final-review.md`**

Insert `Before you finish, read references/deferred-findings.md and run it.` followed by one blank line, directly above the `### Finish` line. Nothing else in the file changes.

- [ ] **Step 5: Set the spec's status**

In the spec, change `Status: awaiting owner approval.` to `Status: approved by the owner.`

- [ ] **Step 6: Run the checks and the repo tests**

Run: `bash /tmp/check-deferred-findings.sh && bash tests/sdd-helper-paths/test-sdd-helper-paths.sh && bash tests/skill-layout/test-no-dev-files-in-skills.sh && bash tests/skill-size/test-skill-size.sh`
Expected: `PASS`, then `PASS: all 15 relative helper references…`, `PASS: no skill ships…`, `PASS: every SKILL.md is under 20000 bytes`.

- [ ] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/references/deferred-findings.md skills/subagent-driven-development/references/final-review.md docs/superpowers/specs/2026-11-10-sdd-deferred-findings-round-design.md
git commit -m "feat(sdd): deferred-findings round after the final whole-branch review"
```
