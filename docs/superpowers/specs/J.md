# J: A split into plans needs a reason

## Intent

Every plan pays the full cost of a chain: a design, a plan and its tasks
file, implementer and reviewer dispatches, a branch, a merge menu, a close
and the record writes. Sessions split work into more plans than its
subsystems justify, and nobody checks the cuts. Each cut should pass one
rule, in every place a cut is made. Issue #6 on aardwulf89/superpowers.

## Evidence

From Lairage. Sessions are in
`~/.claude/projects/-home-alex-Projects-lairage/`.

- **Spec P** (session `685efd21`). Brainstorming wrote six phases into the
  spec, under "Phases (proposal for `chaining-plans`)". The reason given
  was "The phases split where the code splits". But two of the phases
  changed the same part, one phase held only readings, and one held only a
  close. The partner judged three plans to be enough.
- **Phase designs carry a self-made "The plan(s)" section.** No skill asks
  for one. It first appears in the design of D3 and D4, and later designs
  copy it: D6, D7, D8a, D8d, D8e, D9, D10, D15 and D16b2. In it the design
  agent proposes parts, for example "The work has a seam, so it can be two
  plans" (D8a), "D9 splits into three plans" (D9), and "one plan for each
  part" (D16b2). The D8d session splits "following the D8a precedent".
- **The Plan stage carries out the cut with no question.** It calls the
  cut "a re-plan ruling" of the Scope Check of `writing-plans`. That check
  names independent subsystems. But D8d, D8e and D9 split one feature into
  parts that depend on each other. D9 split before `writing-plans` was even
  loaded.
- **No size reason.** Only D15 gives a task estimate (about 20 + 25). The
  others give none, and some parts came out small: D16b2a has 4 tasks and
  D9b has 8.
- **The parts are chained by order.** D16b2's five parts each depend on the
  one before. Only the first link is a real dependency. This is the error
  that H fixed for tasks ("Plan order … never reasons"), one level up.
- **The sound splits came from the partner.** D16 (a rig session whose
  facts the code needs) and D16b were cut by the partner's answers or by
  the phase's Limits line. None of the splits that agents made alone was
  put to the partner.

## Goals

- Every split into plans passes one rule. A cut that fails the rule stays
  one plan.
- Only the places that are allowed to cut do so. A design or a spec
  describes the work, and never divides it into plans.
- The parts of a split wait only on the parts whose code they need.

## Non-goals

- The task level. The fold-in rule of `skills/shared/task-format-reference.md`
  already covers it.
- Any change to how a phase is built, reviewed, merged or closed, beyond
  the split points named below.
- Re-cutting existing efforts, such as Lairage's D.

## Anti-goals

- A ban on splitting. The subsystem split is sound (the partner).
- A list of acceptable reasons that the agent fills in to justify a cut it
  already wants.
- A size split made without the partner.

## Approaches

1. **The rule at every split point (chosen).** It lives in one place, and
   each point that cuts points to it. Each point cut on its own in the
   evidence, so each needs the rule.
2. **Criteria that each phase names** (the issue's proposal). Rejected:
   spec P already named a criterion-shaped reason for each cut ("where the
   code splits"). A list gives the agent the words, not a check.
3. **One spec, one plan.** Rejected by the partner as a flip: independent
   subsystems are a sound split.

## The rule

This is the block, word for word, that each place below holds:

> **Splitting into plans.** Each plan costs a design, reviews, a branch
> and a merge. Split only where:
>
> 1. neither part needs the other's code; or
> 2. a later part needs facts only an earlier part's running code shows.
>    Research that needs no code belongs in the brainstorm.
>
> A split for size, or to merge a part first, is your human partner's
> call: propose it, never rule it.
>
> Never reasons: a seam or section in a design, a precedent, a topic, a
> part that only researches or wraps up.
>
> A part waits on another only when it needs that part's code, never for
> work order.

## Design

**One block, word for word, at every split point.** The rule above goes,
as one identical block of text, into each place below. No place points to
another skill for it, and no copy is reworded. Each place keeps its own
lines about what it does around the block.

| Place | What changes around the block |
|---|---|
| `writing-plans`, Scope Check | The block replaces the current text ("suggest breaking this into separate plans — one per subsystem"). |
| `brainstorming`, Size the Work | The block replaces "If this is really several independent projects, say so…". The spec describes the work and proposes no phases or plans. Research that needs no code happens before the doc. |
| `chaining-plans` Create, step 1 | The block governs the drafted phases. Phases that the spec proposes are tested against it, not copied. |
| `chaining-plans` Resume, Design stage | The block, and: the design describes the phase and never divides it into plans. |
| `chaining-plans` Resume, Plan stage | The block, and: a split that passes it is a re-plan ruling. A size split goes to the partner as a question. |
| `chaining-plans` Close, re-plan rulings | The block governs "a split … that keeps the outcome". |

`chaining-plans/references/record.md`, the split rules: "If a later part
builds on the code of an earlier part, the later part depends on it" gets
the block's last sentence ("A part waits on another only when it needs
that part's code, never for work order.").

**Tests:**
- One test extracts the block from each of the six places and fails if any
  copy differs from the others.
- Text checks: the old Scope Check line ("one per subsystem") and the old
  brainstorming line are gone. The Design stage forbids dividing the phase
  into plans. The record rule holds "never for work order".

## Left to the builder

- The markers that delimit the block, so the test can extract it (an HTML
  comment pair is the default).
- How a size question reaches the partner in Resume. Follow the existing
  `partner_questions` path, if it fits.
- The version bump, with `scripts/bump-version.sh`.
