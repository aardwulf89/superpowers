# K: The record keeps what the brainstorm learned

## Intent

A long brainstorm can do an effort's research: a map of the code it
touches, facts from outside the repo, what was ruled out and why, and
standing rules the partner set along the way. `chaining-plans` gives none
of this a home before phase 1. `learned` exists only in a phase's
`closing`, which is null until that phase's first stage ends, so phase 1,
which needs the research most, has to rediscover it. Issue #7 on
aardwulf89/superpowers, from Lairage spec S.

## Goals

- The record has an effort-level `learned`, seeded by Create from the
  session that approved the spec.
- Every Design stage reads it, before the `closing.learned` of done phases.
- Each close keeps it short and true, as it does with `closing.learned`.
- Create copies the partner's standing rules from the brainstorm into the
  "Across phases" line, and the hand-over names them.
- `record.py` reads and writes the key, so it is never written by hand.

## Non-goals

- No change to `brainstorming`. If Create runs in a session that holds no
  brainstorm, it seeds nothing and says so in the hand-over (the partner
  picked this over having brainstorming write a notes file).
- No new place for intent. Intent stays in the umbrella.

## Anti-goals

- A dump. The seed follows the rules of `closing.learned`: short, true
  against `base`, no project rules, no bookkeeping, nothing the spec
  already says.
- Breaking existing records. A record without the key still works.

## Approaches

1. **A top-level `learned` list in the record, next to `umbrella` and
   `base`.** Picked. It is one source of truth, its edits are checked by
   exact line, and it reuses `set-closing-key`'s modes. Trade-off: a code
   map gets broken into one-line JSON entries, and a line can point at a
   longer file when something does not fit.
2. **A committed markdown notes file that the record links to.** Fits a
   code map better, but it would be edited by hand, losing the
   exact-line check, and pruning on close becomes freeform.
3. **A fake phase 0 holding the seed in its `closing.learned`.** Dropped:
   `pick` and `phase-state` would read it as `not-started` and need
   special cases throughout.

## Design

- **Record shape** (`references/record.md`): a top-level `learned`, null
  or a list of strings. Absent counts as null.
- **`record.py`:**
  - `new-record` accepts `learned` (null or a list of strings) and refuses
    any other type.
  - `get-effort REC learned` prints it as compact JSON (`null` if absent).
  - `set-effort-key REC learned MODE (--value | --value-file)`, with
    `append`, `replace` and `edit` behaving exactly like `set-closing-key`
    (shared code). It refuses any key other than `learned`.
- **Create** (`references/create.md`):
  - Step 4 seeds `learned` in the value file it gives `new-record`. What
    goes in: the map of the code the effort touches (behavior plus how to
    find it), where the research lives (record ids, capture paths), and
    what was ruled out and why. Each repo claim is checked against `base`
    as close step 1 checks lines. Findings from outside the repo stay as
    the brainstorm found them. If the session holds no brainstorm, the
    seed is `[]`.
  - Step 3/4: the partner's standing rules from the brainstorm go into the
    "Across phases" line, shown in the sitting so the partner can correct
    them.
  - Step 5's hand-over reports how many seed lines it wrote (or that it
    found no brainstorm) and which standing rules it copied.
- **Resume Design** (`references/resume.md`): inputs gain the effort
  `learned` (`record.py get-effort REC learned`), listed before the done
  phases' `closing.learned`.
- **Close 1a** (`references/close.md`): it also revises the effort
  `learned`, with the same drop and correct rules, written with
  `set-effort-key … edit`. "Used up" applies only when every phase is done
  or dropped.
- **`SKILL.md`**: the "`closing` carries knowledge forward" paragraph
  mentions the effort-level list, and the Red Flags row about editing by
  hand names `set-effort-key`.
- **Tests:** command tests for `new-record`, `get-effort` and
  `set-effort-key` (including an old record without the key), and updated
  text pins in `tests/chaining-plans/`.

## Left to the builder

The wording in each reference file, the exact help text, and the test
layout, following the existing patterns.
