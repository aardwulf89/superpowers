# C: chaining-plans carries only what is worth carrying, and loses no partner item

## Intent

Across the phases of an effort, `chaining-plans` should carry forward only
knowledge that is true and useful to the later Design stages. It should
hold every item that only the human partner may settle until the partner
gives it a disposition. Open items may carry forward unsettled: the
partner does not want to settle each finding as it appears. The defect is
that items get lost, or an agent settles them by precedent. The skill
tracks only its own knowledge. Anything that belongs in the project's
docs is for the implementers, or for the partner's manual decision.

Issue: aardwulf89/superpowers#1.

## What breaks today

Evidence: a survey of two efforts in one downstream project. It covered
all 490 `closing` lines of a 16-phase effort, a second pass on the 230
lines that matter (every `learned` line, every question, every moved
item, every correction), and a sample of a second, 12-phase effort. Six
of the eight patterns found in the first effort hold in the second.

The skill carries knowledge for two jobs, and it has one channel for each.
Both channels leak.

1. **Agent to agent: `learned`, read by every later Design stage.** Each
   close appends lines, and nothing ever revisits them. Of the 107
   `learned` lines of the first effort, 40 are false now (33 went stale
   and 7 were wrong when written), 43 carry no value, and 43 repeat
   another line or a committed doc. Most of the stale lines name code
   identifiers that later renames broke. Lines that told the reader how to
   find the code, such as a grep, stayed true. False lines misled later
   work. For example, one taught a wrong rule for debt numbers, a later
   phase followed it, and the partner had to reverse the result. Of the
   230 lines, 176 could have been judged when they were written.
2. **Agent to partner: `partner_questions`, brought back by the intent
   round.** `close.md` sends an item there only when it changes the
   intent of a phase that is not done. Everything else falls into
   `unfinished` or the close's report, and no stage reads either again.
   Of 76 items that were the partner's to settle, 30 were never settled,
   and agents settled 11. One open question ("skill edits get no
   RED/GREEN pressure tests") was re-ruled by precedent in six phases in a
   row, and a plan finally wrote the skip into its build rules. In the
   second effort, every item placed in a phase's `partner_questions` was
   answered, and no item placed anywhere else was.
3. **The effort boundary.** When `pick` prints `none`, Resume reports that
   the effort is done and stops. No stage of a later effort reads an
   earlier effort's record. An item left open at the end is lost.
4. **The same item in three copies.** In both efforts, one item sits in
   `unfinished`, `learned` and `replan` at once, and the copies drift
   apart.

Not a cause: no observed loss came from losing `effort.json` itself.

## Approaches

- **Seal the two existing channels (chosen).** Keep the record's shape,
  but for one effort-level flag.
  Curate `learned` as a whole at each close. Give the partner's items one
  findable place and a disposition at the end of the effort. Let the next
  Create read the items that the partner carried. This fixes the leaks
  where they are and adds no third channel.
- **One typed entry per item, enforced by the script (rejected by the
  partner).** It replaces the four `closing` keys. That is a rewrite of
  the data, and it fixes more than the bug.
- **Persist first: commit a knowledge file per effort (dropped).** This is
  the lead direction of issue #1. It keeps the false lines safe without
  fixing them, and no loss was observed from the file.

## Design

### 1. Partner items

- **A partner item** is anything only the partner may settle: an intent
  question, a borderline call, a decision a stage deferred.
- **The interim default** is what later stages do until the partner
  answers. It is the option that commits to nothing new and can be
  reversed, which is usually the status quo. The agent never chooses among
  the options. Picking a default by preference would settle the item.
- **Blocking means no such default exists.** The item cannot wait, so it
  goes to the `partner_questions` of the phase that it blocks, and that
  phase's intent round asks it, as today. A Design stage still stops for
  such a question.
- **A non-blocking item stays in `unfinished` of the phase that raised
  it,** as one line with the fixed prefix `Partner item: `. Any stage may
  write one, and the close sorts every `unfinished` line, including the
  lines copied from the executor, which does not know the prefix. Each
  item line states:
  - what is open;
  - the phase that raised it;
  - its options, when settling it means a choice;
  - its interim default;
  - its cost of waiting, when each later phase makes the answer dearer
    (for example: "until answered, builds skip the pressure tests; each
    skill edit made meanwhile is untested").

  It is worded as an entry, not as a question to answer now.
- **No stage settles a partner item.** A Design stage that meets one
  writes its interim default into the design and cites the item, so the
  plan and the executor follow the default and make no new ruling.
  Following the default is never logged as a ruling. Only the partner's
  answer changes an item.
- **An item that turns out to block.** When a later Design stage finds
  that an item changes its phase's intent, it adds the item to that
  phase's `partner_questions`, and the original line points to it.
- **A dropped phase's blocking question** becomes a non-blocking item, so
  the drop does not lose it.
- **A discard** keeps the phase's partner items and drops the rest of its
  `closing`. The rebuild adds no second copy of an item.
- **Each close's report gives one line:** "Open for you: N new items (M in
  all). They wait for the end of the effort; nothing waits on them." It
  asks nothing.
- **The partner may answer an item at any time.** The answer goes into the
  "Answers:" line of the raising phase's entry in the umbrella's Phases
  section, and the item's line gets its disposition. Folding in any answer
  runs the close's re-plan step (step 2 of `close.md`) over the phases
  that are not done, since they may have been built on the default.

### 2. The end of the effort

An effort is closed out only when every partner item has a disposition.

- **The disposition** is a suffix on the item's line: `[settled]`,
  `[dropped]` or `[carried]`. A settled item names the phase whose
  "Answers:" line holds its answer. Only the partner gives a disposition.
- **`record.py pick`** prints a new value, `items`, when every phase is
  done or dropped but some partner item, in any phase (a dropped one
  included), has no disposition. `none` now means "closed out".
  `open-efforts` lists an effort that is in that state.
- **A record from before this change** has no marked lines, so the script
  cannot vouch that nothing is open. For such a record, `pick` prints
  `unmarked` in place of `none`, and the last message says that open
  items may exist outside the marks. The script knows a record is
  marked by an effort-level `"marked": true`, which Create writes. This
  is the one addition to the record's shape. (Repairing a live record is
  a separate task, see Non-goals.)
- **An answer at the end round that calls for work** may add a phase,
  through a re-plan that the partner directs. `pick` then prints `id:`
  again.
- **The end round.** On `items`, from the final close or from Resume, the
  session shows every open item, with its phase, its options and its
  interim default. It asks the partner for a disposition of each, in one
  round, and ends its turn.
- **The last message of the effort** must leave no room to assume that the
  work is closed out. It leads with one of two first lines:

  ```
  Effort K is finished, but NOT closed out: 3 items stay open, carried past this effort.
  They live only in this machine's record (.superpowers/chain/K/effort.json), not in the repo.
  The next effort's Create will show them to you. Work done outside chaining-plans will not.

  Carried:
  1. [K5] <the item, with its interim default>
  2. ...
  Settled: 9 (answers in the umbrella, Section <n>). Dropped: 2.
  ```

  ```
  Effort K is closed out: every phase is done or dropped, and no item is open.
  ```

  The end round's own message also says that the effort is not closed out
  yet, and why.

### 3. Carried items reach the next effort

- **`record.py carried`** lists each `[carried]` line from the records of
  every effort under the chain directory, with its effort and phase. It is
  one read command, and the shape of the record does not change.
- **Create** runs it at the intent sitting, where the partner is present.
  It shows each carried item. The partner adopts it into a phase of the
  new effort, carries it again, or drops it. An adopted item becomes part
  of that phase's intent, in its Phases entry, so the new record starts
  with no open item. The old line's suffix becomes `[adopted by <phase
  id>]` or `[dropped]`. This is the one place where the skill reads
  another effort, and it reads only its own items.

### 4. `learned` stays small and true

The close maintains the live `learned` as a whole, in three steps:

1. **Check before writing.** Each line of this phase is checked against
   `base`, or against the branch tip while the phase is not merged: every
   name it states exists, and every claim holds. A line
   states a behavior and how to find the code (a grep, a citation of a
   source), and never names an identifier as current truth without that
   check.
2. **Revise (a new step, between steps 1 and 2 of `close.md`).** Read the
   `learned` of every done phase. For each line, decide:
   - drop it when it is used up (its target phase is done and took it), is
     stale against `base`, or repeats another line or a committed doc;
   - correct it when the correction is known;
   - otherwise keep it.

   Write each changed list back with `set-closing-key … learned replace`.
   The partner items are not touched here.
3. **One copy of a moved finding.** The finding's text lives only in its
   destination: the target phase's plan or design, or a `learned` line
   naming that phase. Its `unfinished` line keeps only the pointer.

The Design stage still reads the `learned` of every done phase. After
revision, that is a small set that stays true.

### What does not change

- The record's shape, but for the effort-level `"marked"`. `record.py`
  gains `carried`, and the `items` and `unmarked` values of `pick`, with
  tests.
- `rulings`. No stage reads them as guidance, and an open item's default
  replaces the precedent chain.
- The umbrella holds intent only. A settled answer goes there, as today.
- The skill writes no project doc.

## Files

- `skills/chaining-plans/SKILL.md`: "What carries forward" names the two
  channels and the rule that no stage settles a partner item.
- `skills/chaining-plans/references/close.md`: the check before writing;
  the revise step; one copy of a moved finding; the partner-item line; the
  report line; the end round and the last message.
- `skills/chaining-plans/references/resume.md`: Pick handles `items`.
  Design writes the interim default of an open item. Answers given
  outside a round are folded in.
- `skills/chaining-plans/references/create.md`: the carried items at the
  intent sitting.
- `skills/chaining-plans/references/record.md`: the `Partner item: `
  prefix, the dispositions, `carried`, and `pick`'s `items`.
- `skills/chaining-plans/scripts/record.py` and its tests under
  `tests/chaining-plans/`.

## Non-goals

- **Persistence of the record.** No observed loss came from the file. The
  last message prints the carried items in full, so the transcript keeps a
  copy.
- **Knowledge across efforts.** The skill's scope is one effort. Only
  partner items cross the boundary, and only when the partner carries
  them.
- **Writing to the project's docs, or correcting a phase's committed
  design.** That is for the implementers, or the partner.
- **Repair of an effort already under way.** Migrating a live record is a
  separate task for the partner, after this lands.

## Risks

- Revise and check-before-writing are prose that agents follow. The check
  is the RED/GREEN pressure tests of `writing-skills` on the edited
  references.
- Dispositions are text conventions that the script parses. Its tests pin
  the prefix and each suffix.

## Calls made while writing this design

Made by the designer, open to the partner's correction:

- An adopted carried item becomes intent in the new effort's Phases
  entry; it is not an open item in the new record.
- A settled answer goes into the raising phase's "Answers:" line.
- Folding in an answer runs the re-plan step.
- The end round may add a phase.
- The check before writing uses the branch tip while the phase is not
  merged.
- `"marked"` and `pick`'s `unmarked` keep an old record from reading as
  closed out.

The partner approved the rule of the interim default and the meaning of
blocking.

## Left to the builder

- The exact wording of the report line and of the end round.
- How `carried` finds the records (the existing `chain-dir` logic).
