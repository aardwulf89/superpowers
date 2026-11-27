# Create: the intent sitting

Your human partner is present and has just approved a spec that needs
several plans. In this sitting, and only here, they decide the intent of
every phase. After it, each phase runs in its own session without them, up
to its merge menu.

Create writes nothing until your human partner answers: no Phases
section, no record, no commit, no plan, and no change to the record of
another effort.

When step 1 finds the spec's letter, make the step tasks, as `SKILL.md`
§ Tasks says:
1. Use `TaskCreate` to make 1 step task for each step: `"Draft the phases (K)"`,
   `"Find the open intent questions (K)"`, `"Run one sitting (K)"`,
   `"Write it down (K)"`, `"Hand over (K)"`. Each title is its step's
   heading, word for word.
2. Block each task by the task before it, with `TaskUpdate`
   (`addBlockedBy`).

A task stays in_progress while its step waits on your human partner. If
step 4 uses a different letter, retitle each task with `TaskUpdate`. Leave
every other task in the list alone, brainstorming's included: they belong
to the skills that made them, and they end with this session.

## 1. Draft the phases

- **Find the umbrella spec.** It is the `<spec path>` argument, or the spec
  this session just approved. If the session holds no spec, ask which spec
  to use. Stop until your human partner answers.
- **Find `base`,** the branch every phase merges into.
  - If the main checkout is on the repository's default branch, that
    branch is `base`. The default branch is the one
    `git symbolic-ref --short refs/remotes/origin/HEAD` names, without
    `origin/`. With no remote, it is `main` or `master`.
  - If the main checkout is on any other branch, ask which branch is `base`
    in the sitting (step 3).
- **Find the spec's letter.** It is the id on the spec's first line
  (`# K: …`), and it is the effort id. If the spec predates ids (a dated
  file name, no letter on its first line), give it a letter now. Run
  `bash ../brainstorming/scripts/next-spec-id` by its absolute path, from
  the main checkout. Step 4's commit issues the letter. Until then, the
  letter and the phase ids can change.
- **Check for an existing effort.** If `docs/superpowers/efforts/<id>.json`
  already exists in the main checkout, this spec is already an effort. Say
  so, and point your human partner at Resume.
- **Work from the spec and from the reasons for the split** that the
  session holds, such as the Scope Check of `writing-plans` that found
  several subsystems.
- **For each phase, draft:**
  - an id: the spec's letter plus a number in work order (`K1`, `K2`, …).
    Ids carry no words. If a plan for this spec already has an id (`K1`),
    its phase keeps that number. The other phases take the numbers that no
    plan ever used, in work order;
  - a title;
  - its purpose and its limits: what it builds, and what it leaves to other
    phases;
  - `depends_on`: the phases whose code it builds on (build order);
  - `waits_on`: each question that the plan of an earlier phase must answer
    before this phase can be designed, and which phase answers it
    (knowledge order). Put every phase in `waits_on` also in `depends_on`:
    the phase cannot start before its question is answered, and Resume's
    pick reads only `depends_on`.
- **Order the phases** in the order of work. Each phase comes after every
  phase it depends on and every phase it waits on.

## 2. Find the open intent questions

An intent question is a question that the spec does not answer, and whose
answer changes what a phase builds. Examples: who a feature is for, what is
in or out of scope, a preference between outcomes, a rule that cuts across
phases.

Technical questions are not intent questions. Examples: how to build it,
which library, which data structure, a format that a measurement will
decide, a technical choice that every phase will share (such as the
language or the runtime). Decide them when the phase is designed, with what
earlier phases learned. If you ask them now, you freeze a guess.

## 3. Run one sitting

**First, read the carried items.** Run `record.py carried`. Each entry is a
partner item that an earlier effort carried past its end. The entry's
effort is the name of its `record` file, without `.json`.

Show your human partner, in 1 message:
- the phases in order, as a numbered list: id, title, purpose, and what
  each phase depends on and waits on;
- the intent questions, in 1 round, most important first, each naming the
  phase it shapes;
- an invitation to correct the phase list (add, drop, merge, split,
  reorder) in the same reply;
- the standing rules that your human partner set in the brainstorm, as
  drafted into the "Across phases" line, for them to correct;
- each carried item, with its effort and phase, and a question in the same
  round: adopt it into a phase of this effort (which one), carry it again,
  or drop it;
- the question of which branch is `base`, if step 1 found that it is a
  question.

If `carried` printed `[]`, say nothing about carried items.

Then end your turn and wait for the answers. Write nothing while the
sitting is open. If an answer opens a new intent question, ask it before
you write.

If your human partner defers a question ("decide it later"), it stays open.
Put it in that phase's `partner_questions`. Resume asks it when the phase
comes up.

## 4. Write it down

Do all of this in the main checkout, on `base`.

1. **Add the Phases section** to the umbrella spec, in the format below.
   Fold in your human partner's answers and corrections. Put an adopted
   carried item in its phase's entry, in the "Answers:" or "Limits:" line.
   For a spec that predates ids:
   - Run `bash ../brainstorming/scripts/next-spec-id` by its absolute path
     again.
   - If it now prints a different letter, use that letter. Renumber the
     phase ids to match.
   - Stamp the letter into the spec's first line as
     `# K: <its existing title>`. The file keeps its name.
2. **Plans already written.** Before Create runs, the session can have
   written plans for this spec: none, the plan of the first phase, or
   several.
   - **Link a plan only to a phase with no `waits_on`.** Set that phase's
     `plan` to the plan's path, and its `spec` to the plan's Spec path.
     Then Resume neither designs nor re-plans the phase. Do not rewrite the
     plan.
   - **A plan for a waiting phase** assumed answers that nobody has yet. Do
     not link it. Name it in the hand-over, and leave it for your human
     partner to keep or delete. Its phase keeps the plan's number either
     way. If the plan is deleted, never give that number to anything else.
3. **Check that `.superpowers/` is ignored.** Run
   `git check-ignore -q .superpowers`. If it is not ignored, add
   `.superpowers/` to `.gitignore`: an untracked file there stops the
   next Resume, which needs a clean tree.
4. **Write the record** with `record.py new-record`
   (`references/record.md` § Commands):
   - Write the whole record as JSON to a value file.
   - Run `record.py new-record
     <main checkout>/docs/superpowers/efforts/<id>.json --value-file <path>`.

   Use the shape that `references/record.md` gives:
   - `umbrella`: the spec's repo-relative path; `base`: the branch;
   - `learned`: the seed (below);
   - `phases`: in the order of work;
   - `status`: `needs-partner` if it has `partner_questions`, else `waiting`
     if it has `waits_on`, else `known`;
   - `spec` and `plan`: null, except for a linked plan. `closing`: null.

   **The seed** is what the session's brainstorm found that every phase
   needs, as a list of lines. Every phase's Design reads it. It holds:
   - the map of the code the effort touches: each line states a behavior
     and how to find its code;
   - where the research lives: record ids, capture paths;
   - what was ruled out, and why.

   Leave out what `references/close.md` step 1 ("Write `learned`") leaves
   out, and what the spec already says. Check each line against `base` as
   that step does. If the session holds no brainstorm, the seed is `[]`.

   If the command fails, it wrote nothing. Correct the value file and run
   it again.
5. **Mark the carried items** that your human partner adopted or dropped,
   in the old record, at the `record` path that `carried` printed. The
   `[carried]` at the end of the line becomes `[adopted by <phase id>]` or
   `[dropped]`. For each item:
   - Write a value file with 1 `[old, new]` pair:
     `{"edit": [["<item>", "<the new line>"]]}`. Copy `item` exactly as
     `carried` printed it.
   - Run `record.py set-closing-key <record> <phase> unfinished edit
     --value-file <path>`.
   - If it refuses because the line is not there, read
     `record.py get <record> <phase> closing.unfinished`, find the item's
     line by its text, and edit that line.

   Leave an item that was carried again as it is.
6. **Commit** in 1 commit on `base`, with the letter in the subject
   (`docs(K): phases`). Put these in the commit:
   - the spec;
   - the new record;
   - any old record you marked;
   - any plan you linked;
   - `.gitignore`, if it changed.

   This commit issues the ids. From here on, never renumber them.

### The Phases section

Append it to the umbrella spec. Resume copies a phase's entry word for word
into that phase's design, together with the "Across phases" line. So each
entry, read with that line, must stand on its own. Do not repeat a
cross-phase rule inside the entries.

```markdown
## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** <rules that cut across phases, from your human partner's
answers and the standing rules they set in the brainstorm: intent only,
never a technical choice; or "none">

### K1: Storage

- **Purpose:** <what this phase builds and why>
- **Limits:** <what it does not do, and which phase does>
- **Answers:** <each intent question about this phase, with your human
  partner's answer in their terms; "deferred: <question>" for one they put
  off; or "none asked">
- **Depends on:** <phase ids, or "none">
- **Waits on:** <for each question: the phase that answers it, and the
  question; or "none">
```

## 5. Hand over

Report, briefly:
- the commit that added the Phases section;
- the record's path, `docs/superpowers/efforts/<id>.json`;
- the seed: how many lines it holds, or that the session held no
  brainstorm;
- the standing rules copied into the "Across phases" line;
- each carried item, and whether it was adopted, carried again or dropped;
- each plan you linked, and each plan you did not link, for your human
  partner to keep or delete;
- the first phase the next session will run.

Then ask your human partner to clear the session and invoke the skill in a
fresh session (for example: "Use superpowers-extended-cc:chaining-plans to
continue the effort."). Do not start the first phase in this session.
