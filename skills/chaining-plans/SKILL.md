---
name: chaining-plans
description: Use when your human partner asks to chain a spec that needs several plans, to continue the next plan of an effort, or when closing a plan of an effort after its merge menu
---

# Chaining Plans

Carry one effort, a spec too big for one plan, from plan to plan on rails.
Each plan gets its own fresh session. Between plans, your human partner
reviews what happened, clears the session, and starts the next session with
one entry prompt.

## Overview

An effort has 2 kinds of design decisions. You make them at different times.

**Your human partner decides intent up front, for every phase.** Intent is
what each phase is for, its limits, their preferences, and the rules that
cut across phases. Intent does not depend on what earlier phases find. Their
attention is the scarce resource: 1 sitting, then a long unattended run.

**You alone do the technical design, just in time.** When its session starts, write a
phase's design. Use what earlier phases learned and what the brainstorm
found (the effort's `learned`). Stay inside the intent your human partner
set.

**This split gives the test between plans.** If a plan's results
change an intent decision, ask your human partner. If they change only
technical detail, rule and report.

An effort has 3 entry points:
1. **Create:** the intent sitting, when a spec needs several plans.
2. **Resume:** the entry prompt of each fresh session. It settles what the
   last session left, picks the next phase, and runs it to the merge menu.
3. **Close:** after the merge menu, the skill invokes itself. It writes what
   the plan learned and re-plans the phases after it.

## The Standing Approval

**When your human partner invokes this skill, they give standing approval
for everything the session does up to the merge menu.** Their instructions
take precedence over skills (`using-superpowers`), and this invocation is
that instruction. The approval covers:

- **The phase's technical design.** Do not open a brainstorm for it. The
  umbrella spec's approval and the intent sitting replace a brainstorm.
- **The Execution Handoff of `writing-plans`.** The handoff asks your human
  partner, in 1 `AskUserQuestion`, how to execute the plan. Answer it
  yourself: **Subagent-Driven (this session)**, the default of
  `writing-plans`. Log the answer as a ruling. Ask no question. A chain
  never picks a Parallel Session: both Parallel Session options open a
  second session, and the chain's session must build its own phase. If a
  session is nearly out of context, it stops as any stage stops, and the
  next session resumes the phase.
- **The worktree consent of `using-git-worktrees`.** The stated preference
  is a worktree. If the project's instructions say to build in place, the
  phase builds on its own branch in the main checkout. The approval covers
  work on the phase's own branch only, never on `base`.
- **The missed git ops at Resume.** If your human partner did not merge a
  finished phase, the next Resume merges it before anything new starts.

When you invoke `superpowers-extended-cc:writing-plans`, put this line in
the same message, so its handoff does not stop the session:

> Standing approval from `chaining-plans`: your human partner's invocation
> covers this plan's Execution Handoff. Do not ask it: the method is
> Subagent-Driven (this session). Commit the plan and its tasks file, then
> invoke `superpowers-extended-cc:subagent-driven-development`.

**What it does not cover:**
- Intent. A question whose answer changes what your human partner
  intended is theirs. Ask it, or record it for them. Never rule on it.
- The executor's own stop conditions. They still stop the build.
- The merge menu. `finishing-a-development-branch` shows it in its own
  words, and your human partner answers it. "git ops" means:
  1. Option 1 (merge locally).
  2. Push `base`.
  3. If the remote branch exists, delete it.

  If the branch has an open PR, "git ops" means: merge that PR.

## Routing

Route by the arguments. If there are none, your human partner's request
decides. A request that is neither to create nor to close is Resume.

| Arguments | Entry point | Read |
|---|---|---|
| `create [<spec path>]`, or a request to chain or split a spec | Create | `references/create.md` |
| none, or an effort id, or a request to continue | Resume | `references/resume.md` |
| `close <effort id> <phase id>` | Close | `references/close.md` |

The paths are relative to this skill's base directory, not the project. At
every invocation, read the file fresh with the Read tool, even if you read
it before. Follow it: it is the entry point.

## Where Things Live

**Ids.** The effort id is the umbrella's spec letter (`K`, from the first
line `# K: …`). A phase id is that letter plus a number (`K3`). Create
issues phase ids in work order. A split appends a lowercase letter (`K3a`),
and the bare id still names the whole. The phase id is also:
- the plan id that `writing-plans` uses (its tasks are `K3.1`, `K3.2`, …);
- the name of the branch when the phase is built in place;
- the id in the phase's docs commit subjects: `docs(K3): …` in a repo that
  uses conventional commits, else `K3: …`.

Ids are fixed once committed. Never renumber them, reuse them or give them
to other work. Copy them verbatim into everything you write to the record
or report.

**The intent lives in the umbrella spec,** committed on `base`. Create adds
a `## Phases` section to the approved spec. For each phase, the section
holds its purpose and limits, your human partner's answers, and what it
depends on and waits on.

**Each phase's technical design** goes in
`docs/superpowers/specs/<phase id>.md`, with first line
`# <phase id>: <title>`, committed on `base`. The design copies the phase's
entry from the Phases section word for word, with the section's "Across
phases" line. It does so because the executor reads only the plan and its Spec. If the
umbrella already covers a phase in enough detail, the phase needs no
separate design, and its `spec` links the umbrella.

**Each plan** goes where `writing-plans` puts it
(`docs/superpowers/plans/<phase id>.md`). `writing-plans` commits it with its
tasks file on `base` before the build: the executor reads both from inside
the worktree.

**The record holds the machine state.** It is one JSON file per effort, at
`docs/superpowers/efforts/<id>.json` of the main checkout, committed on
`base`. Make every write to the record in the main checkout, on `base`, and
commit it (`references/record.md`).
- `references/record.md` gives the record's shape and the commands of
  `scripts/record.py`. Run each by the script's absolute path, as 1 plain
  command. Never edit the record by hand or rewrite it from memory.
- Your human partner never reads the record. They review through your
  reports.

**Branches: one lane.** Each phase gets its own branch and worktree. The
executor's own worktree setup creates them from `base`. Merge each phase
into `base` before the next phase starts. The phase id names the branch:
Claude Code's `EnterWorktree` names it `worktree-<phase id>`. If the
project's instructions say to build in place, the phase builds in the main
checkout, on a branch named `<phase id>`. Create that branch from `base`
before the executor starts. Commit the docs (the Phases section, phase designs, plans) and
the record on `base` in the main checkout, never on a phase branch.

**`closing` carries knowledge forward.** When it finishes, the executor
deletes its workspace, the ledger included. Never read the ledger of another
plan. The build's "Rulings I made" and "Unfinished", from the executor's
final message, travel with the build:
1. Before finishing starts, write them to the build results file,
   `docs/superpowers/plans/<phase id>.build.json`.
2. Commit it on the phase branch.

The close copies them into `closing`. `learned` carries knowledge to later
Design stages. The effort has a `learned` of its own: Create seeds it from
the brainstorm, and every Design stage reads it. Each close keeps both
`learned` lists small and true. A `Partner item:` line in `unfinished`, or
a question in `partner_questions`, holds what only your human partner
settles. No stage settles it. An effort is closed out only when each item has your
human partner's disposition and none is `[carried]`.

## Tasks

Every task this skill makes is a step task: a step of Create, an action of
Resume step 3, or a stage of Resume step 6. Its title is `<name> (<id>)`:
the step's fixed name, then its effort or phase id in brackets
(`Draft the phases (K)`, `Missed close (A2)`, `Build (A3)`). Give it none
of the headings of a work task (Goal, Files, Acceptance Criteria, Verify),
and never a `json:metadata` block: pcvelz's TaskCreate hooks then treat it
as a step task. Before you make one, check `TaskList`. If a task with that
title exists, use it.

The plan's own tasks (`A3.1: …`) are work tasks. `writing-plans` makes
them, and the executor runs and finishes them. Never make, change or finish
a work task here. Never make a task for Close: the caller's task covers it.

## Invoke the Skills, Don't Recall Them

An agent that knows a skill tends to act from memory: in a later session,
or late in a long session after compaction. Both skip steps.

- **Every stage that names a skill invokes it fresh through the Skill
  tool.** Do this even if you believe you know the skill, and again after
  compaction. Announce each stage, as `using-superpowers` requires.
- **The close is its own invocation of `chaining-plans`,** with
  `close <effort id> <phase id>`. Never do it from memory of what Resume
  said hours earlier.
- **A stage is done only when its "Done when" holds.** A missing artifact
  means you recalled the skill and did not follow it. Go back and invoke it.

## Red Flags

These thoughts mean STOP: you are leaving the rails.

| Thought | Reality |
|---------|---------|
| "I ran this loop last session" | Invoke it anyway. Read the entry point's reference file fresh. |
| "I'll just write the plan" | Invoke `writing-plans`. |
| "The close is just updating the JSON" | Invoke `chaining-plans` with `close <effort id> <phase id>`. |
| "I remember what the reference file says" | Read it. It is the entry point. |
| "I'll fix the record by hand" | Run `record.py set`, `record.py set-closing-key` or `record.py set-effort-key` (`references/record.md`). |
| "This phase needs a brainstorm first" | The intent sitting replaced it. Design inside the Phases entry. |
| "I should ask how to execute the plan" | The standing approval answers the handoff: Subagent-Driven (this session). Continue. |
| "While they're here, I'll design every phase" | Up front is intent only. Technical design waits for the phase's session. |
| "This change is small, I'll rule on it" | If it changes what your human partner intended, it is theirs to answer. |
| "I'll start the next phase in this session" | One plan per session. Hand over and stop. |
