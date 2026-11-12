# Chaining plans: design

Status: approved by the human partner, 2026-11-12.

## Intent

A goal that needs several plans should run on rails from one plan to the
next. Between plans, the human partner reviews what happened, clears the
session, and starts the next one with one entry prompt. They should not
have to work out the orchestration themselves.

## The problem

**The split happens too late.** Brainstorming usually writes one design.
Later, `writing-plans`' Scope Check finds that it needs several plans,
and only *suggests* "breaking this into separate plans". By then the
conversation with the human partner is over:
- every decision they made assumed one design;
- the later phases have no decisions of theirs behind them;
- nobody reviews the split;
- the split and its reasons live only in that session's conversation.

**Nothing connects one plan to the next.** Each skill stops at its own
boundary:
- `subagent-driven-development` and `executing-plans` end by deleting the
  plan's workspace. Its rulings ("Rulings I made") and open findings
  ("Unfinished") reach only the final message.
- `finishing-a-development-branch` ends at cleanup.

**Later phases depend on what earlier ones find out.** The order of the
phases mixes two kinds of dependency:
- **build order:** a later plan builds on an earlier plan's code;
- **knowledge order:** a later phase's design depends on what an earlier
  plan finds out.

Superpowers records neither, and nothing carries what a plan learned into
the phases after it.

### Evidence

Two projects built their own harness for this on the same day: a one-line
resume skill pointing at a hand-kept status file. One is a native PC port
of a decompiled game (nine phases). The other is the drag-feedback parity
work of a pseudo-OS (seven phases). Their specs were written as multi-phase
specs on purpose; one is titled "the order of work". The status files
grew in reaction to problems during sessions and are not a design. They
contradict each other ("do the next action, and only that" against "keep
going").

Both decided everything up front: recon of every phase, a full design of
every phase, and one sheet of decisions answered in one sitting. Their
records then show knowledge changing between plans, and later designs
being fixed by hand. Examples: "the rig measured Tight, so Tight works;
open fact X5 is new", "open fact X6 dropped", "plan 5F after a recon of
the labels". To cope, they added staleness checks, lists of open facts,
verifier agents, and "the plan's first task checks the design against the
code".

## The model: intent up front, technical design just in time

The design decisions split into two kinds, and each kind is made at a
different time.

**Intent is decided up front, for every phase, with the human partner.**
- What each phase is for: its goals and limits, the human partner's
  preferences, and the rules that cut across phases.
- These don't depend on what earlier phases find out, and they are best
  decided with the whole picture in view.
- The human partner's attention is the scarce resource. One sitting,
  followed by a long unattended run, beats pulling them in for every
  phase.
- This is what both source projects got right.

**Technical design is done just in time, by the agent alone.**
- Each phase's design is written when its session starts. It uses what
  earlier phases learned, and stays inside the intent the human partner
  set.
- Detailed designs written up front freeze guesses, and later results
  break them. This is what both source projects got wrong.

**The test between plans follows from the split.** When a plan's results
would change an intent decision, the human partner is asked. When they
only change technical detail, the agent rules and reports.

## Goals

1. **An intent sitting at the split.** When a spec turns out to need
   several plans, the human partner sees the phases, their order, and
   what each waits on. They answer the intent questions that the spec
   leaves open, in one sitting.
2. **A record of the effort.** It holds the phases, their order, and
   their dependencies, both build and knowledge.
3. **A session per plan, straight through.** One entry prompt starts a
   fresh session. It designs, plans, builds, and reaches the merge menu,
   with no stops except at the intent test.
4. **A close after each plan.** It writes down what the plan learned,
   re-plans the later phases, applies the intent test, and reports.

## Constraints

- The human partner is the only user of this fork. Its tools may depend
  on `jq` and `gh`.
- The human partner never reads the record by hand. The agent works with
  it through commands, and the human partner reviews through the agent's
  reports.
- No existing skill changes. The human partner rejected adding hand-off
  lines to `brainstorming`, `writing-plans` and
  `finishing-a-development-branch` as changing the parent skills too
  much.

## Non-goals

- Several plans in one session. The human partner clears the session
  between plans.
- Detailed design of every phase up front, or verifier agents for it.
- The process of either source project: recon waves, rig or emulator
  queues, cost caps on agent briefs, stopping at a fixed share of the
  context.
- Replacing the source projects' harnesses (`/port`, `/drag-parity`).
  They stay as they are for their in-progress work. This skill is for
  future efforts.

## Anti-goals

- A ruling that silently changes what the human partner intended.
- State that is kept by hand, or that repeats what files and git already
  say.
- Protocol copied into each project.

## Approaches

**A. One new user-level skill, invoked by the human partner, with no
change to any existing skill (picked).** The skill owns the record, the
intent sitting, the entry prompt, and the close. It runs the existing
skills as stages.

What A costs:
- Nothing starts the record by itself: the human partner invokes the
  skill when they see the split.
- The close depends on the skill's own instructions surviving a long
  session, rather than on a hook in `finishing`. The next resume catches
  a missed close (see Resume).

**B. Hand-off lines in the existing skills (rejected by the human
partner).** `writing-plans` would create the record, `finishing` would
run the close, and `writing-plans` would skip its plan review. Rejected
because it changes the parent skills too much.

**Full designs of every phase up front (rejected).** This is what the
source projects did. It freezes technical guesses that later plans
break.

**Brainstorm each phase just in time with the human partner
(rejected).** It keeps designs fresh, but it pulls the human partner in
for every phase, and it gives up deciding intent with the whole picture
in view.

## Design

Calls marked "(my call)" are the designer's; the rest were decided by
the human partner.

### The skill

`chaining-plans`, a user-level skill available in every project. Its
records live in `.superpowers/chain/` (name and abbreviation: my call).

It has three entry points:
1. **Create:** the human partner invokes it when a spec turns out to need
   several plans, usually right after `writing-plans` splits it.
2. **Resume:** the human partner invokes it in a fresh session. This is
   the entry prompt.
3. **Close:** the skill invokes itself after the merge menu.

**Invoking it is the human partner's standing approval** for everything
the session does up to the merge menu: the phase's design, `writing-plans`'
plan review, the choice of execution method, and the worktree consent of
`using-git-worktrees` (see How it meets the rest of the flow). The human partner's
instructions take precedence over skills (`using-superpowers`). The skill
states this at the point where it invokes `writing-plans`, so the
plan-review wait does not stop the session. The port harness already
relies on the same rule ("Invoking this skill is the owner's `go`").

### Where things live

**The intent lives in the umbrella spec,** which is committed (my call).
- Create adds a **Phases** section to the approved spec. For each phase,
  it gives the purpose and limits, the human partner's answers, and what
  the phase waits on.
- The human partner's decisions go into git, next to the spec they
  extend.

**Each phase's technical design** goes in
`docs/superpowers/specs/<date>-<umbrella topic>-<phase id>-design.md`,
committed (my call). It cites the phase's entry in the umbrella's Phases
section. When the umbrella already covers a phase in enough detail, that
phase needs no separate design, and its `spec` links the umbrella.

**The record holds the machine state.**
- Location: `<main checkout>/.superpowers/chain/<id>/effort.json`.
  - The main checkout is the parent of
    `git rev-parse --path-format=absolute --git-common-dir`, so a
    session in a worktree finds the same record (my call).
  - `<id>` is the basename of the umbrella spec (my call).
- `.superpowers/` is git-ignored, so the record is never committed.
- The record lasts until the effort is done, and it is kept after that
  (my call).
- It is one JSON file, updated in place with `jq` (`jq '…' effort.json >
  effort.json.tmp && mv effort.json.tmp effort.json`). It keeps no
  history.

**Shape** (my call):

```json
{
  "umbrella": "docs/superpowers/specs/<date>-<topic>-design.md",
  "base": "main",
  "phases": [
    {
      "id": "p2-runtime",
      "title": "Runtime libraries",
      "status": "waiting",
      "depends_on": ["p1-executor"],
      "waits_on": [
        { "from": "p1-executor", "question": "Which intrinsics differ from the reference in the executor's calibration?" }
      ],
      "partner_questions": [],
      "spec": null,
      "plan": null,
      "branch": null,
      "closing": null
    }
  ]
}
```

- **The array order is the order of work.**
- `status` holds only what can't be read from elsewhere:
  - `known`: ready to design;
  - `waiting`: on its `waits_on`;
  - `needs-partner`: has intent questions in `partner_questions`;
  - `dropped`.
- `depends_on` is build order. `waits_on` is knowledge order: each entry
  names a question and the phase whose plan must answer it.
- `spec`, `plan` and `branch` are links, filled in as the work creates
  them.
- **Done is derived, not stored** (my call). A phase whose `branch` is
  set is done when one of these holds:
  - the branch exists and is an ancestor of `base`
    (`git merge-base --is-ancestor`);
  - the branch no longer exists. Finishing deletes a branch only after
    merging it (option 1); a discard resets `branch` to null (see Close);
  - `gh pr view <branch> --json state` says `MERGED`, which covers a
    squash or rebase merge, where the tip never becomes an ancestor.
- `closing` is created when the phase's first stage ends:

```json
{
  "rulings": ["every ruling of the phase's design, plan and build, including each 'Rulings I made' line"],
  "unfinished": ["each 'Unfinished' line, with the phase it was moved to, or 'none' and why"],
  "learned": ["the answer to each waits_on question this phase was meant to settle, then the surprises"],
  "replan": [
    { "intent": false, "borderline": false, "change": "…", "affects": ["p3-types"], "why": "…", "alternative": "…" }
  ]
}
```

  `rulings` and `unfinished` fill in as each stage ends, so the close
  does not depend on context surviving compaction. `learned` and
  `replan` stay null until the close.

### Branches and worktrees: one lane

**Each phase gets its own branch and worktree, and is merged into `base`
before the next phase starts.** The human partner merges it with `git
ops` at the merge menu (their global instructions: merge, push, delete
the branch). This is the only lane.

- **Worktrees.** The human partner never creates one. The executor's own
  setup (`using-git-worktrees`) creates a fresh worktree and branch from
  `base` at the start of each build. The standing approval answers its
  consent prompt. Finishing's option 1 removes the worktree after the
  merge. A project whose instructions say to build in place builds on a
  branch in the main checkout instead; the lane is otherwise the same.
- **Git ops between plans: yes, every time.** The next phase builds on
  the previous phase's code, so that code must be on `base`. The merge
  menu is where the human partner comes in anyway, so `git ops` is their
  one reply at each boundary.
- **Not merging** (option 2 or 3) is supported only as a wait. Phases that
  depend on the unmerged phase stay blocked until it merges, and Resume
  goes on with phases that don't depend on it.
- **Docs live on `base`.** The umbrella spec, its Phases section, each
  phase's design, and each plan are committed on `base` in the main
  checkout, before the build's worktree is created.

**Why this lane (my call).** Every existing skill runs as written:
- `using-git-worktrees` makes one worktree per build;
- the executor's final review diffs against the merge base with `base`,
  which is exactly this phase's work;
- `finishing` runs its menu once per plan.

**The rejected lane: one long-lived branch and worktree per effort,**
merged once at the end. It would spare the `git ops` at each boundary,
but at the cost of overriding two existing behaviors on every plan:
- the executor's final review would diff from the effort's start, taking
  in every earlier phase;
- finishing would have to be skipped between phases.

Overrides like these are what agents drop when they work from memory.

### Create: the intent sitting

The human partner is present, having just approved the spec.

1. **Draft the phases.**
   - Work from the spec and from the reasons for the split that the
     session holds.
   - If the session holds no spec, ask which one to use.
   - For each phase, give its id, title, purpose, `depends_on`, and
     `waits_on` questions.
2. **Find the open intent questions.** These are the questions, for each
   phase, whose answer changes what the phase builds and that the spec
   does not answer. Technical questions are not on this list. They are
   decided when the phase is designed.
3. **Run one sitting.** Show the phases, their order, and what each waits
   on. Ask the intent questions in one round, most important first. Take
   corrections to the phase list in the same round.
4. **Write it down.**
   - Add the Phases section to the umbrella spec, with the answers, and
     commit it on `base`.
   - Write `effort.json`.
   - If a plan was already written in this session, link it; don't
     rewrite it (my call).
5. **Hand over.** Ask the human partner to clear the session and invoke
   the skill.

### Resume: the entry prompt

1. **Find the record.** List `.superpowers/chain/*/effort.json` under the
   main checkout, and drop the efforts that are done.
   - If none is left, say so: an effort starts with Create.
   - If one is left, use it.
   - If several are left and the prompt names none, ask which.
2. **Check git:** the main checkout, a clean tree.
3. **Pick the phase.** It is the first, in array order, that is not done
   and not `dropped`, and whose `depends_on` are all done. First, read
   the state of any phase whose `branch` is set from what git and the disk
   show (my call):

   | Branch | Its SDD workspace | `closing.replan` | State | Action |
   |---|---|---|---|---|
   | exists, not merged | exists | null | Build cut off | Re-invoke the executor in the branch's worktree (`git worktree list`). It resumes from its own ledger |
   | exists, not merged | gone | null | Build done, finishing not run | Invoke finishing, then close |
   | merged or gone | — | null | Close missed | Close first, reconstructing `learned` from the plan and the branch's commits |
   | exists, not merged | — | set | Awaiting merge (option 2 or 3) | Skip; its dependants stay blocked |
   | merged or gone | — | set | Done | — |

   - If the pick is `waiting`, a close should have resolved it. Report the
     inconsistency and stop.
   - If nothing qualifies but phases remain, report what blocks them and
     stop.
4. **Run the stages straight through to the merge menu.**

   | Stage | What it does | Done when |
   |---|---|---|
   | Intent round (only if `needs-partner`) | Ask the human partner the `partner_questions`, fold the answers into the umbrella's Phases section, commit, set `known` | The answers are committed |
   | Design (only if no `spec`) | Write the phase's technical design inside its intent. A fresh reviewer reads it with `skills/brainstorming/builder-check-prompt.md`. Its questions: technical ones, the agent settles and logs as rulings; intent ones, stop and ask the human partner | The design file is committed and linked |
   | Plan (only if no `plan`) | Invoke `writing-plans`. Standing approval: no plan-review wait. Pick the execution method by its recommendation rule, as a ruling | The plan file, with `writing-plans`' header, is committed and linked |
   | Build | Invoke the chosen executor. Its worktree setup creates the branch; record `branch` as soon as it exists. The executor runs unchanged, with its own four stop conditions | The executor's final message holds "Rulings I made" and "Unfinished", and both are copied into `closing` before finishing starts |
   | Finish | Invoke `finishing-a-development-branch`. The human partner answers its menu | The menu was shown as `finishing` words it, and answered |
   | Close | Invoke `chaining-plans` again to close | `closing.replan` is written and the report given |

### Close

It runs after finishing options 1, 2 and 3. After a discard it does not
run: the skill sets the phase's `branch` back to null and its status to
`known`, and the human partner, who is present, directs what happens next
(my call).

It runs from the main checkout. After option 2 or 3 the session may still
be in the worktree, so its git commands use `git -C <main checkout>`.

1. **Write `learned`.**
   - Answer each `waits_on` question in the record whose `from` is this
     phase.
   - Add the surprises.
   - Check that `rulings` and `unfinished` hold every line of the
     build's final message. Add any that are missing.
2. **Re-plan the phases that are not done.** For each change that what
   was learned causes, apply the **intent test**. Does the change alter
   any of these?
   - the umbrella's goals, non-goals or anti-goals;
   - a phase's purpose or limits in the Phases section;
   - an answer the human partner gave;
   - which phases exist, in a way that changes the outcome.

   **No:** the agent rules on its own and applies the change. That
   includes reordering, a split or merge that keeps the outcome,
   resolving `waits_on`, setting a waiting phase to `known`, changing a
   phase's technical design (committed on `base`), and moving each
   unfinished finding to the phase it belongs to.

   **Yes:** don't rule. Add the question to the affected phase's
   `partner_questions` and set it to `needs-partner`.

   **When in doubt, automate:** rule it, and mark it `borderline`.
3. **Report**, in this order:
   - the borderline rulings;
   - the questions for the human partner, and which phase waits on them;
   - the other rulings;
   - what the next session will do, or that the effort is done.

   Ask the human partner to clear the session and invoke the skill.

### How it meets the rest of the flow

Each touchpoint, in the order a run meets it. For each, what the other
skill does (from its text), and what `chaining-plans` does about it.

**1. Session start: `using-superpowers`.**
- It says to brainstorm before building, and to invoke every skill that
  applies.
- A resumed session must not open a brainstorm for the phase's design.
  The skill says so: the umbrella approval and the intent sitting replace
  it. The human partner's instructions outrank skills, and invoking
  `chaining-plans` is that instruction.

**2. Before Create: `brainstorming`, then `writing-plans`.**
- Brainstorming's hard gate leads to `writing-plans`. Its Scope Check
  only *suggests* a split, so by the time the human partner invokes
  Create, the session may already have written plans: none, the first
  phase's, or several.
- Create links an existing plan only to a phase with no `waits_on`. A
  plan for a waiting phase assumed answers nobody has yet. Create does
  not link it, names it in the hand-over, and leaves it for the human
  partner to keep or delete (my call).

**3. Design stage: what it reads.**
- **Inputs:** the whole umbrella, including the phase's entry in its
  Phases section; `closing.learned` of every phase that is done, above
  all the phases named in this phase's `waits_on`; and the code on
  `base`.
- **The phase's intent goes into the design.** The design copies the
  phase's entry from the Phases section word for word (my call).
  `writing-plans` takes one Spec path, and executors read only the plan
  and that Spec. Without the copy, the intent never reaches the build.
- **The reviewer prompt.** The builder-check prompt is read from
  `../brainstorming/builder-check-prompt.md`, relative to the skill's own
  base directory. That is the installed plugin, not the project.
- **Commit** the design on `base`, in the main checkout.

**4. Plan stage: `writing-plans`.**
- **Its header** makes the phase's design the plan's **Spec**.
- **Its Scope Check** may want to split this phase further. That is a
  re-plan with no change to intent: split the phase in the record, log a
  ruling, and plan the first part.
- **Its Execution Handoff** waits for a review even when the method is
  supplied. The standing approval covers that wait. The method comes from
  its recommendation rule, logged as a ruling.
- **Commit the plan on `base` before the build starts** (my call). The
  executor resolves the plan file from inside the worktree, so a plan
  that isn't committed is missing there.

**5. Build stage: the executor and `using-git-worktrees`.**
- **The worktree consent prompt.** Both executors set up the workspace
  through `using-git-worktrees`. Its Step 0 asks for consent before
  creating a worktree, unless the human partner's instructions already
  state a preference. The standing approval states one: use a worktree,
  unless the project's instructions say to build in place (my call). This
  also covers "never start implementation on main without consent".
- **The SDD ledger** lives in the worktree, at
  `<worktree>/.superpowers/sdd/<plan>/`. The record lives in the main
  checkout, and the agent finds it from inside the worktree through
  `--git-common-dir`.
- **Running.** The executor runs unchanged, with its own four stop
  conditions. It reads only the plan and its Spec.

**6. The executor's finish: the progress file of a plan.**
- At its finish, the executor writes "Rulings I made" and "Unfinished"
  into its final message. It then deletes its workspace, ledger included,
  and says "Use superpowers:finishing-a-development-branch".
- **`chaining-plans` never reads a previous plan's ledger.** By the time
  the next plan starts, the ledger has been deleted, and both executors
  say "Another plan's directory is never yours to read or write". What
  carries forward is `closing`, which is copied from the final message.
- **This is the one point where the skill steps in during the build.**
  Between the final message and finishing, copy both lists into
  `closing`. A missed copy is caught at the close, which checks the lists
  against the final message, while the session still holds it.
- **The only ledger the skill ever relies on is the current plan's own**,
  after a cut-off build. Even then the skill doesn't read it: it
  re-invokes the executor, which resumes from it.
- **When Claude Code runs the plan through an orchestrator subagent**
  (its tool notes), the orchestrator's final message carries the lists
  verbatim, and they are copied from that.

**7. Finishing: `finishing-a-development-branch`.**
- **Step 1** runs the full suite. A red suite stops it before the menu,
  as it does today.
- **Step 3** asks for the base branch if it isn't known. The skill gives
  it the record's `base`.
- **Step 4** shows the menu to the human partner.
- **Option 1** merges into `base`, deletes the branch, removes the
  worktree, and leaves the session in the main checkout.
- **Options 2 and 3** keep the branch and the worktree.

**8. The close, then the next session.**
- The close runs in the main checkout (see Close).
- The next session's Resume reads the state of the phase from git and the
  disk (see the table under Pick), not from memory.

### Invoke the skills, don't recall them

An agent that knows a skill tends to act from memory instead of invoking
it. This happens in a later session, where it remembers `chaining-plans`
from an earlier run. It also happens late in a long session, where after
compaction it paraphrases `writing-plans` or the executor. Both skip
steps. The human partner raised this failure mode.

- **Every stage that names a skill invokes it fresh through the Skill
  tool.** This holds even when the agent believes it knows the skill, and
  again after compaction. Each stage is announced, as `using-superpowers`
  requires.
- **The close is its own invocation of `chaining-plans`.** It is not done
  from memory of what resume said hours earlier.
- **A stage is done only when its "Done when" holds.** A missing
  artifact means the skill was recalled rather than followed. Go back and
  invoke it.
- **The skill carries a Red Flags table** in the form of
  `using-superpowers`' table. Examples:
  - "I ran this loop last session" → invoke it anyway.
  - "I'll just write the plan" → invoke `writing-plans`.
  - "The close is just updating the JSON" → invoke `chaining-plans`.

### What does not change

- Every existing skill.
- Single-plan work, which never invokes `chaining-plans`.

### Left to the builder

- The split of `chaining-plans` into `SKILL.md` and reference files.
- The `jq` commands the skill shows.
- The wording of the standing approval where the skill invokes
  `writing-plans`.
- The tests. The repo requires eval evidence for skill changes. The
  skill is edited by hand, not through `writing-skills`.
