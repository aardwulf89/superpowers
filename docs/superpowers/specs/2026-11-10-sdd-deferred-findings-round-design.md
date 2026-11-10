# Design: SDD deferred-findings round

Date: 2026-11-10. Size: small change. Status: awaiting owner approval.

## Intent

Subagent-driven-development leaves recorded work unfinished. Task-review
Minors are ledgered as `minor (deferred)` and never enter the fix loop;
re-review out-of-scope observations go the same way; the breaker parks real
findings "nothing downstream builds on"; the whole-branch review triages the
pile and its single fix wave fixes only some of it. Whatever it skips is
dropped. Dropping recorded findings is incomplete work, not a cost saving.

The working-deferred-minors skill exists to clean this up after the fact
(archive harvesting, LLM auditors, quote checks, a `minors/*` branch). It was
built outside SDD because "a fork is a maintenance burden". The owner now
maintains a fork, so the fix goes in SDD itself.

## Goals

- Every finding the run deferred is completed before SDD finishes, if it can
  be.
- Anything that cannot be completed reaches the owner explicitly, as
  unfinished work, with what was tried.

## Non-goals

- Changing when or why SDD defers during the run. Per-task deferral stays as
  upstream has it.
- Changing the ledger's line formats, the reviewer prompts, or the fix loop.

## Anti-goals

- Edits to upstream files beyond one pointer line. Every upstream edit is a
  merge cost on each release.
- A step that re-derives the leftover list from a summary or category list
  instead of from the ledger itself.

## Constraints

- The ledger (`<workspace>/progress.md`) is the only surviving record of what
  was deferred. The round runs off it as written.
- The controller never fixes findings itself (SDD rule).
- Every dispatch names its model (SDD Model Selection).
- **No improvised wording.** `deferred-findings.md` mirrors the existing
  references (`final-review.md`, `fix-loop.md`) in structure, voice, and
  phrasing, so it carries no behavior the rest of SDD doesn't already have:
  - Open the way the other references do: `# <Title>`, then
    `Part of superpowers:subagent-driven-development. <when this applies>.`
  - Where a step matches an existing one, copy that text verbatim and adjust
    only the nouns: the fix wave's dispatch and its single scoped re-review
    (`final-review.md`), the fixer's "fixes, re-runs the tests covering the
    amended code, appends its fix report" contract and the check that the
    fix report holds the covering tests, the command run, and the output
    (`fix-loop.md`).
  - Use the existing fixed phrases as they are: "by its absolute path, from
    the working tree you're executing in"; "on the most capable available
    model (see SKILL.md's Model Selection)"; "Never fix findings yourself in
    the controller session"; and backticked ledger lines shaped like
    `Task <N>: fix round <R>/5 (...)`.
  - New wording only where this step really differs: the fixer reads the
    whole ledger to infer what is open, and the "Unfinished" heading.

## Approaches

Considered:

- **A. Minors enter each task's fix loop** like any finding. Rejected by the
  owner: per-task deferral exists for a reason (loop length and convergence).
- **B. Minors ride along only in fix rounds already happening.** Rejected:
  still drops minors on tasks with no other findings.
- **C. The whole-branch fix wave must fix every deferred minor.** Rejected
  with the others.
- **Normalising ledger lines** (one `(deferred)` shape, `parked` reserved for
  "reviewer wrong") so the round is a grep. Rejected by the owner: it edits
  upstream files, and a fixer can read the whole ledger and infer what is
  open.

**Chosen (owner's design):** one new fix/review round that runs after the
whole-branch review's fix wave and re-review, working off the full ledger.

## Design (decided)

- **New file:** `skills/subagent-driven-development/references/deferred-findings.md`,
  the deferred-findings round.
- **Trigger:** the only upstream edit is one line in
  `references/final-review.md`, immediately before `### Finish`:
  "Before you finish, read references/deferred-findings.md and run it."
- **Naming:** prose in the new file calls the existing step "the whole-branch
  review". Upstream's file and text keep "final".
- **The round:**
  1. The controller dispatches ONE fixer on the most capable model with the
     ledger path, the plan path, and the workspace's report files for detail.
  2. The fixer reads the entire ledger, infers every finding still open
     (deferred minors, out-of-scope observations, real findings parked at the
     cap, whole-branch residuals), fixes them, runs the covering tests, and
     returns the list of findings it treated as open with what it did for
     each.
  3. ONE scoped re-review (`re-review-prompt.md`, review package over the
     round's fix range) verdicts each item on that list and flags new
     breakage in the fix diff.
  4. The controller ledgers the result. There is no second round.
- **Unfinished:** anything still open after the re-review goes in the final
  message under an "Unfinished" heading, each item with what was tried. The
  new file instructs this; the Finish text is untouched.

## Left to the builder (my calls, owner to check)

- The fixer's dispatch text lives inline in `deferred-findings.md`, as the
  whole-branch fix wave's does, rather than in a new template file. The
  re-review is a separate dispatch from `re-review-prompt.md`, as in every
  other fix round; the fixer's list of what it treated as open is that
  template's findings list.
- Findings ruled "the reviewer is wrong" (code stands) are not reopened; the
  fixer reads the ruling and leaves them. They still appear under "Rulings I
  made".
- Pre-existing-code observations in the ledger count as open work.
- If a fix needs a decision only the owner can make, the fixer does not
  guess: the item goes to "Unfinished" with the question.
- Exact ledger wording for the round's result line, and the re-reviewer's
  model per Model Selection.
