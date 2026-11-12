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
- **Check for an existing effort.** The effort id is the spec's basename
  without `.md`. Run `chain-dir` from `references/record.md`; if
  `<chain_dir>/<id>/effort.json` already exists, this spec is already an
  effort. Say so, and point your human partner at Resume.
- **Work from the spec and from the reasons for the split** that the session
  holds, such as `writing-plans`' Scope Check finding several subsystems.
- **For each phase, draft:**
  - an id, `p<n>-<slug>` (for example `p1-storage`), and a title;
  - its purpose and its limits (what it builds, and what it leaves to other
    phases);
  - `depends_on`: the phases whose code it builds on (build order);
  - `waits_on`: each question an earlier phase's plan must answer before this
    phase can be designed, and which phase answers it (knowledge order).
- **Order the phases.** The order is the order of work: each phase comes after
  every phase it depends on and every phase it waits on.

## 2. Find the open intent questions

An intent question is one whose answer changes what a phase builds, and that
the spec does not answer: who a feature is for, what is in or out of scope,
a preference between outcomes, a rule that cuts across phases.

Technical questions are not on this list: how to build it, which library,
which data structure, the format a measurement should decide. They are
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

If the main checkout is not on the branch the phases should merge into, ask
which branch is `base` in the same round.

Then end your turn and wait for the answers. Do not write anything while the
sitting is open. If an answer opens a new intent question, ask it before writing.

If your human partner defers a question ("decide it later"), it stays open:
it goes into that phase's `partner_questions`, and Resume asks it when the
phase comes up.

## 4. Write it down

All of this happens in the main checkout, on `base`.

1. **Add the Phases section** to the umbrella spec, in the format below, with
   your human partner's answers and corrections folded in.
2. **Plans already written.** By the time Create runs, the session may have
   written plans for this spec: none, the first phase's, or several.
   - **Link a plan only to a phase with no `waits_on`.** That phase's `plan`
     is the plan's path, and its `spec` is the plan's Spec path, so Resume
     neither designs nor re-plans it. Don't rewrite the plan.
   - **A plan for a waiting phase** assumed answers nobody has yet. Don't link
     it. Name it in the hand-over, and leave it for your human partner to keep
     or delete.
3. **Check that the record is ignored:** `git check-ignore -q
   .superpowers/chain`. If it is not, add `.superpowers/` to `.gitignore`;
   an untracked record would leave the tree dirty for Resume.
4. **Commit** the spec, any plan you linked, and `.gitignore` if it changed,
   on `base`.
5. **Write `effort.json`** at `<chain_dir>/<id>/effort.json` (run
   `chain-dir`, then `mkdir -p` the effort's directory). This one write
   creates the whole file, in the shape `references/record.md` gives:
   - `umbrella`: the spec's repo-relative path; `base`: the branch;
   - `phases`: in the order of work, every phase with all ten keys;
   - `status`: `needs-partner` if it has `partner_questions`, else `waiting`
     if it has `waits_on`, else `known`;
   - `spec` and `plan`: null, except for a linked plan; `branch` and
     `closing`: null.

   Pipe it through `jq .` so a malformed record fails here. Every later change
   goes through `set`.

### The Phases section

Append it to the umbrella spec. Resume copies a phase's entry word for word
into that phase's design, so each entry must stand on its own.

```markdown
## Phases

The order below is the order of work. Each phase gets its own plan, branch
and session.

**Across phases:** <rules that cut across phases, from your human partner's
answers; or "none">

### p1-storage: Storage

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
