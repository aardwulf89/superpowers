---
name: chaining-plans
description: Use when your human partner asks to chain a spec that needs several plans, to continue the next plan of an effort, or when closing a plan of an effort after its merge menu
---

# Chaining Plans

Carry one effort, a spec too big for one plan, from plan to plan on rails.
Each plan gets its own fresh session. Between plans your human partner
reviews what happened, clears the session, and starts the next one with one
entry prompt. They never work out the orchestration themselves.

## Overview

The design decisions of an effort are of two kinds, made at different times.

**Intent is decided up front, for every phase, with your human partner.**
What each phase is for, its limits, their preferences, and the rules that cut
across phases. None of this depends on what earlier phases find out, and it is
best decided with the whole picture in view. Their attention is the scarce
resource: one sitting, then a long unattended run.

**Technical design is done just in time, by you alone.** A phase's design is
written when its session starts. It uses what earlier phases learned, and it
stays inside the intent your human partner set. A detailed design written up
front freezes guesses that later results break.

**The test between plans follows from the split.** When a plan's results
would change an intent decision, ask your human partner. When they only change
technical detail, rule and report.

An effort has three entry points:
1. **Create:** the intent sitting, when a spec turns out to need several plans.
2. **Resume:** the entry prompt of each fresh session. It settles what the
   last session left, picks the next phase, and runs it straight through to
   the merge menu.
3. **Close:** after the merge menu, the skill invokes itself to write down what
   the plan learned and re-plan the phases after it.

## The Standing Approval

**Invoking this skill is your human partner's standing approval for
everything the session does up to the merge menu.** Their instructions take
precedence over skills (`using-superpowers`: "User instructions ... take
precedence over skills"), and invoking `chaining-plans` is that instruction.
It covers:

- **The phase's technical design.** Do not open a brainstorm for it: the
  umbrella spec's approval and the intent sitting replace one.
- **`writing-plans`' plan-review wait.** Its Execution Handoff asks for a
  review before implementation. Do not wait for it.
- **The execution method.** Pick it by `writing-plans`' recommendation rule,
  and log the choice as a ruling.
- **The worktree consent of `using-git-worktrees`.** The stated preference is
  a worktree, unless the project's instructions say to build in place; then
  the phase builds on its own branch in the main checkout. The approval
  covers implementing on the phase's own branch, never on `base`. It is not
  the consent the executors ask for in "Never start implementation on a
  main/master branch without your human partner's explicit consent": a
  phase never starts on `base`, so that rule does not come up.
- **Resume's missed git ops.** A finished phase your human partner did not
  merge is merged at the next Resume, before anything new starts.

When you invoke `writing-plans`, say so in the same message, so its wait does
not stop the session:

> Standing approval from `chaining-plans`: your human partner's invocation
> covers this plan's review and its execution method. Do not wait for a
> review; pick the method by the recommendation rule and continue.

**What it does not cover:**
- Intent. A question that would change what your human partner intended is
  theirs: ask it, or record it for them. Never rule on it.
- The executor's own stop conditions, which still stop the build.
- The merge menu. `finishing-a-development-branch` shows it as it words it,
  and your human partner answers it. "git ops" means: option 1 (merge
  locally), then push `base`, then delete the remote branch if it exists; or,
  if the branch has an open PR, merge that PR.

## Routing

Route by the arguments. When there are none, your human partner's request
decides; a request that is neither to create nor to close is Resume.

| Arguments | Entry point | Read |
|---|---|---|
| `create [<spec path>]`, or a request to chain or split a spec | Create | `references/create.md` |
| none, or an effort id, or a request to continue | Resume | `references/resume.md` |
| `close <effort id> <phase id>` | Close | `references/close.md` |

The paths are relative to this skill's base directory, not the project. Read
the file fresh with the Read tool at every invocation, even when you have read
it before, and follow it. It is the entry point; this file only holds the
rules all three share.

## Where Things Live

**Ids.** The umbrella's spec letter (`K`, from the first line `# K: …`)
is the effort id. A phase id is that letter plus a number (`K3`), issued
by Create in work order; a split appends a lowercase letter (`K3a`), and
the bare id still names the whole. The phase id is also the plan id that
`writing-plans` uses (its tasks are `K3.1`, `K3.2`, …), the branch name,
and the id in the phase's docs commit subjects (`docs(K3): …` in a repo
that uses conventional commits, else `K3: …`). Ids are fixed
once committed: never renumbered, reused, or given to other work. Copy
them verbatim into everything you write to the record or report.

**The intent lives in the umbrella spec,** committed on `base`. Create adds a
`## Phases` section to the approved spec: for each phase, its purpose and
limits, your human partner's answers, and what it depends on and waits on.

**Each phase's technical design** goes in
`docs/superpowers/specs/<phase id>.md`, with first line
`# <phase id>: <title>`, committed on `base`. It copies the phase's entry from the Phases section word
for word, with the section's "Across phases" line, which is part of every
entry's copy, because the executor reads only the plan and its Spec. When the
umbrella already covers a phase in enough detail, the phase needs no separate
design, and its `spec` links the umbrella.

**Each plan** goes where `writing-plans` puts it
(`docs/superpowers/plans/<phase id>.md`), committed on `base` before
the build starts: the executor resolves it from inside the worktree.

**The record holds the machine state:** one `effort.json` per effort, at
`<main checkout>/.superpowers/chain/<id>/effort.json`, where `<id>` is the
umbrella's spec letter. Run `record.py chain-dir` to find the directory;
it resolves the same from any worktree. `.superpowers/` is git-ignored, so
the record is never committed.
- `references/record.md` holds its shape and every command you run against
  it: the subcommands of `scripts/record.py` (`chain-dir`, `open-efforts`,
  `phase-state`, `pick`, `get`, `questions`, `new-record`, `set`,
  `set-closing-key`, `set-phases`), each run by the script's absolute path
  as one plain command. Create writes the record once with `new-record`;
  every later change is `set`, `set-closing-key` or `set-phases`. Never
  edit the record by hand or rewrite it from memory.
- Your human partner never reads the record. They review through your
  reports.

**Branches: one lane.** Each phase gets its own branch, named by its phase
id, and worktree, created
from `base` by the executor's own worktree setup, and is merged into `base`
before the next phase starts. A project whose instructions say to build in
place builds on the phase's own branch in the main checkout instead,
created from `base` before the executor starts; the lane is otherwise the
same. Docs (the Phases section, phase designs, plans)
are committed on `base` in the main checkout, never on a phase branch.

**What carries forward is `closing`.** The executor deletes its workspace when
it finishes, ledger included. Never read another plan's ledger; copy "Rulings
I made" and "Unfinished" from the executor's final message into `closing`
before finishing starts.

## Invoke the Skills, Don't Recall Them

An agent that knows a skill tends to act from memory instead of invoking it:
in a later session, where it remembers this skill from an earlier run, and
late in a long session, where after compaction it paraphrases `writing-plans`
or the executor. Both skip steps.

- **Every stage that names a skill invokes it fresh through the Skill tool.**
  This holds even when you believe you know the skill, and again after
  compaction. Announce each stage, as `using-superpowers` requires.
- **The close is its own invocation of `chaining-plans`,** with
  `close <effort id> <phase id>`. It is not done from memory of what Resume
  said hours earlier.
- **A stage is done only when its "Done when" holds.** A missing artifact
  means the skill was recalled rather than followed. Go back and invoke it.
- **The record changes only through the commands in `references/record.md`.**

## Red Flags

These thoughts mean STOP—you're leaving the rails:

| Thought | Reality |
|---------|---------|
| "I ran this loop last session" | Invoke it anyway. Read the entry point's reference file fresh. |
| "I'll just write the plan" | Invoke `writing-plans`. |
| "The close is just updating the JSON" | Invoke `chaining-plans` with `close <effort id> <phase id>`. |
| "I remember what the reference file says" | Read it. It is the entry point. |
| "I'll fix the record by hand" | Run `record.py set` or `record.py set-closing-key` (`references/record.md`). |
| "This phase needs a brainstorm first" | The intent sitting replaced it. Design within the Phases entry. |
| "I should wait for a review of the plan" | The standing approval covers that wait. Continue. |
| "While they're here, I'll design every phase" | Up front is intent only. Technical design waits for its phase's session. |
| "This change is small, I'll rule on it" | If it alters what your human partner intended, it is theirs to answer. |
| "I'll start the next phase in this session" | One plan per session. Hand over and stop. |
