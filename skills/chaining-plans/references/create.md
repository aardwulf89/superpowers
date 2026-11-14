# Create: the intent sitting

Your human partner is present, having just approved a spec that needs
several plans. This sitting is the one time they decide the intent of every
phase. After it, each phase runs in its own session without them, up to its
merge menu.

Create writes nothing until your human partner has answered: no Phases
section, no record, no commit, no plan.

## 1. Draft the phases

- **Find the umbrella spec.** It is the `<spec path>` argument, or the spec
  this session just approved. If the session holds no spec, ask which one to
  use, and stop until your human partner answers.
- **Find `base`,** the branch every phase merges into. When the main
  checkout is on the repository's default branch, that branch is `base`:
  the one `git symbolic-ref --short refs/remotes/origin/HEAD` names,
  without `origin/`, or, with no remote, `main` or `master`. On any other
  branch, which branch is `base` is a question for the sitting.
- **Find the spec's letter.** It is the id on the spec's first line
  (`# K: …`), and it is the effort id. A spec that predates ids (a dated
  file name, no letter on its first line) gets one now: run
  `bash ../brainstorming/scripts/next-spec-id` by its absolute path, from
  the main checkout. The letter is not issued until step 4 commits it, so
  until then it and the phase ids may change.
- **Check for an existing effort.** The effort id is the spec's letter. Run `record.py chain-dir` (`references/record.md` § Commands); if
  `<chain dir>/<id>/effort.json` already exists, this spec is already an
  effort. Say so, and point your human partner at Resume.
- **Work from the spec and from the reasons for the split** that the session
  holds, such as `writing-plans`' Scope Check finding several subsystems.
- **For each phase, draft:**
  - an id, the spec's letter plus a number in work order (`K1`, `K2`,
    …), and a title. Ids carry no words. A plan already written for this
    spec has an id (`K1`): its phase keeps that number, and the other
    phases take the numbers no plan has used, in work order;
  - its purpose and its limits (what it builds, and what it leaves to other
    phases);
  - `depends_on`: the phases whose code it builds on (build order);
  - `waits_on`: each question an earlier phase's plan must answer before this
    phase can be designed, and which phase answers it (knowledge order).
    Every phase a phase waits on is also in its `depends_on`: it cannot start
    before its question is answered, and Resume's pick reads only
    `depends_on`.
- **Order the phases.** The order is the order of work: each phase comes after
  every phase it depends on and every phase it waits on.

## 2. Find the open intent questions

An intent question is one whose answer changes what a phase builds, and that
the spec does not answer: who a feature is for, what is in or out of scope,
a preference between outcomes, a rule that cuts across phases.

Technical questions are not on this list: how to build it, which library,
which data structure, the format a measurement should decide, a technical
choice every phase will share, such as the language or the runtime. They are
decided when the phase is designed, with what earlier phases learned. Asking
them now freezes a guess.

## 3. Run one sitting

Show your human partner, in one message:
- the phases in order, as a numbered list: id, title, purpose, and what each
  depends on and waits on;
- the intent questions, in one round, most important first, each naming the
  phase it shapes;
- an invitation to correct the phase list (add, drop, merge, split, reorder)
  in the same reply.

If `base` is a question (step 1), ask it in the same round.

Then end your turn and wait for the answers. Do not write anything while the
sitting is open. If an answer opens a new intent question, ask it before writing.

If your human partner defers a question ("decide it later"), it stays open:
it goes into that phase's `partner_questions`, and Resume asks it when the
phase comes up.

## 4. Write it down

All of this happens in the main checkout, on `base`.

1. **Add the Phases section** to the umbrella spec, in the format below, with
   your human partner's answers and corrections folded in. For a spec that
   predates ids, run `bash ../brainstorming/scripts/next-spec-id` by its
   absolute path again: if it now prints a different letter, use that one
   and renumber the phase ids to match. Stamp the letter into the spec's
   first line as `# K: <its existing title>`; the file keeps its name.
2. **Plans already written.** By the time Create runs, the session may have
   written plans for this spec: none, the first phase's, or several.
   - **Link a plan only to a phase with no `waits_on`.** That phase's `plan`
     is the plan's path, and its `spec` is the plan's Spec path, so Resume
     neither designs nor re-plans it. Don't rewrite the plan.
   - **A plan for a waiting phase** assumed answers nobody has yet. Don't link
     it. Name it in the hand-over, and leave it for your human partner to keep
     or delete. Its phase keeps the plan's number either way; if the plan is
     deleted, that number is not given to anything else.
3. **Check that the record is ignored:** `git check-ignore -q
   .superpowers/chain`. If it is not, add `.superpowers/` to `.gitignore`;
   an untracked record would leave the tree dirty for Resume.
4. **Commit** the spec, any plan you linked, and `.gitignore` if it changed,
   on `base`, with the letter in the subject (`docs(K): phases`). This
   commit issues the ids: from here on they are never renumbered.
5. **Write the record** with `record.py new-record`
   (`references/record.md` § Commands): run `record.py chain-dir`, write
   the whole record as JSON to a value file, then run
   `record.py new-record <chain dir>/<id>/effort.json --value-file <path>`.
   This one write creates the whole file, in the shape
   `references/record.md` gives:
   - `umbrella`: the spec's repo-relative path; `base`: the branch;
   - `phases`: in the order of work, every phase with all ten keys, and
     every `waits_on[].from` also listed in that phase's `depends_on`;
   - `status`: `needs-partner` if it has `partner_questions`, else `waiting`
     if it has `waits_on`, else `known`;
   - `spec` and `plan`: null, except for a linked plan; `branch` and
     `closing`: null.

   If it fails, it wrote nothing: correct the value file and run it
   again. Every later change goes through `record.py set`,
   `record.py set-closing-key` or `record.py set-phases`.

### The Phases section

Append it to the umbrella spec. Resume copies a phase's entry word for word
into that phase's design, together with the "Across phases" line, which is
part of every entry's copy. So each entry, read with that line, must stand on
its own; don't repeat a cross-phase rule inside the entries.

```markdown
## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** <rules that cut across phases, from your human partner's
answers: intent only, never a technical choice; or "none">

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
- the record's path;
- each plan you linked, and each plan you did not, for your human partner to
  keep or delete;
- the first phase the next session will run.

Then ask your human partner to clear the session and invoke the skill in a
fresh one (for example: "Use superpowers:chaining-plans to continue the
effort."). Do not start the first phase in this session.
