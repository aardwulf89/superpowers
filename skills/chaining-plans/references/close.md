# Close: what the plan learned, and the re-plan

A close writes what the plan of one phase learned. Then it re-plans the
phases that are not done, and reports. Its invocation is
`close <effort id> <phase id>`. It comes from one of 2 places, and each
place has its own ending (step 4):

- **The plan's own session,** after your human partner answered its merge
  menu.
- **Resume's settle step,** for a phase that is `finished-unclosed` or
  `close-missed`. An earlier session built that phase.

A close makes no tasks of its own. The task that invoked it covers it:
"Close (A3)" or "Missed close (A2)".

Every command in this file is a subcommand of the record script. Run each
one as `references/record.md` § Commands says: one plain command per Bash
call. Put each list of lines in a value file.

## 0. Find the phase, and check the answer to the menu

- **Find the record.** It is `docs/superpowers/efforts/<effort id>.json`
  in the main checkout. If it is missing, or has no phase with that id,
  say so and stop. Give its path as `REC`, and the phase id as `ID`, to
  every later command.
- **Work from the main checkout.** It is the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. After option 2
  or 3, the session can still be in the worktree. If it is an isolated
  worktree (Claude Code, after `EnterWorktree`), first leave it with
  `ExitWorktree`, action `keep`. The isolated worktree refuses git
  commands aimed at the main checkout. Otherwise, run every git command
  as `git -C <main checkout>`. If the phase was built in place and its
  branch is still checked out there, switch to `base` before a commit.
  Switch back after the commit.
- **Copy ids. Never shorten them.** Every line you write to `rulings`,
  `unfinished`, `learned` or `replan` keeps the full ids it names
  (`Task K3.4: …`, `K3: …`). It names a phase by its phase id. A commit
  on `base` carries the narrowest id (`docs(K3): …`).
- **Commit every write to the record before the next step of the
  close.** Commit it in the main checkout, on `base`. Put it in the docs
  commit of the close that it belongs to, or commit it alone as
  `docs(<phase id>): record`.
- **Write `closing` one key at a time,** with `record.py set-closing-key`.
  If a step needs the current value, read only that key, with
  `record.py get REC ID closing.<key>` (`closing.learned`), each time.
  Never use a value from memory.
- **If `replan` is already set,** the phase is closed. Say so, and go to
  the ending (step 4). Never set `replan` back to null.

**Which answer the menu got.** If Resume's settle step invoked the close,
this session had no menu: run steps 1 to 4. In the plan's own session:

- **Option 1, 2 or 3:** run steps 1 to 4. After option 2 or 3, the branch
  is not merged yet. The next Resume does its missed git ops before
  anything new starts.
- **A discard:** do not run a close. The phase now reads `not-started`,
  and its next session builds it again. `set` its `status` to `known`. Then
  read `record.py get REC ID closing.unfinished`. If it is not null, keep
  only its partner items:
  1. The executor's lines have no prefix yet, so
     first sort every `unfinished` line by the sort at the end of step 1.
  2. Write `unfinished` with only the lines that start with
     `Partner item: ` (`record.py set-closing-key REC ID unfinished
     replace`).
  3. Write `rulings` as `[]`
     (`record.py set-closing-key REC ID rulings replace --value '[]'`).

  `learned` and `replan` stay null, because no close ran. Report that,
  and stop. Your human partner is present and directs what happens next.

## 1. Write `learned`

`learned` holds what later phases need from this phase. It holds, in this
order:

- **The answer to each `waits_on` question whose `from` is this phase,**
  in any phase of the record. Find them with `record.py questions REC ID`.
  Each answer names the phase that asked. Answer from what the plan
  found, not from what it set out to find. If the plan did not answer a
  question, write that as its answer.
- **The surprises:** what the build found that its plan did not expect,
  and that the design of a later phase needs to know.

**Leave out what later phases get elsewhere:**

- **A rule that the project already holds.** The project's instructions
  state it (`AGENTS.md`, `CLAUDE.md`, a project skill), or a gate checks
  it (a linter, a hook, a test). Later phases read the instructions and
  meet the gates.
- **Bookkeeping:** that no question names this phase, a merge, a commit
  id, a branch. Git and the record hold it.

**Check each line before you write it,** against `base`, or against
the branch tip while the phase is not merged. Run these commands, with
`<ref>` the record's `base` once merged, else the phase branch
(`worktree-<phase id>`, or `<phase id>` if built in place):

- `git -C <main checkout> grep <name> <ref>`
- `git -C <main checkout> show <ref>:<path>`

Every name that the line states must exist there. Every claim that it
makes about what is there must hold. The check reads the repo only. It
does not redo the research of the build: a finding about anything outside
the repo stays as the build found it. A line states a behavior and how to
find its code (a grep, a cited source). Never state an identifier as
current truth unless you checked it. If a line fails, correct it or leave
it out.

**Read the build results file on `<ref>`:**
`git -C <main checkout> show <ref>:docs/superpowers/plans/<phase id>.build.json`.
It holds the executor's "Rulings I made" (`rulings`) and "Unfinished"
(`unfinished`), in whichever session the close runs. Every line of its
`rulings` must be in `closing.rulings`. Every line of its `unfinished`
must be in `closing.unfinished`. Add each line that is missing. If the
file is on neither `base` nor the phase branch, the build results were
never committed. Then write nothing. Report that to your human partner,
and stop.

**If Resume's settle step invoked the close,** the session of the build
is gone. Reconstruct `learned` from the plan (`plan`, if set) and the
commits of the phase. Read the plan, the messages and diffs of the
commits, and any notes or findings files that they added. The commits of
the phase run from the anchor to the commit that brought
`<phase id>.build.json` into `<ref>`. Run every command as
`git -C <main checkout>`:

- **The anchor** is the commit that added the plan:
  `git log --diff-filter=A --format=%H -1 -- <plan>`. If `plan` is null
  and `spec` is the phase's own design file, it is the commit that added
  that file. If `plan` is null and `spec` is null or the umbrella, it is
  the commit that added the Phases section:
  `git log -S'## Phases' --format=%H --reverse -- <umbrella> | head -1`.
- **The end** is the last commit on `<ref>` that touched the build
  results file:
  `git log --format=%H -1 <ref> -- docs/superpowers/plans/<phase id>.build.json`.
  After a merge or a fast-forward, it is the branch's own results commit.
  After a squash or a rebase, it is the commit that carried the file onto
  `base`.
- **Read** `git log -p --ancestry-path <anchor>..<end>`. The range can
  also hold other commits on `base`: the chain's docs commits, and, after a
  squash or a rebase, anything that landed first. Read the commits whose
  subjects carry this phase's ids (`feat(K3.4): …`, `fix(K3): …`), and
  skip the rest. Always read `<end>` itself: after a squash or a rebase,
  it holds the whole build, whatever its subject says.

Write the results with `record.py set-closing-key`:

- `learned`, with mode `replace`;
- each missing `rulings` or `unfinished` line, with mode `append`.

**Then sort every `unfinished` line** in the record, on every close, the
executor's lines included: the executor does not know the prefix. Read
them with `record.py get REC ID closing.unfinished`.

- **A partner item** is anything that only your human partner
  settles: an intent question, a borderline call, or a decision that a
  stage left to them ("the owner's call", "for the partner to decide").
  Rewrite it as one line that starts with `Partner item: `. The line
  states, in this order:
  1. what is open;
  2. the phase that raised it (`raised by K3`);
  3. its options, if it asks for a choice;
  4. its interim default (step 2 defines it);
  5. its cost of waiting, if each later phase makes the answer more
     costly.

  Write it as an entry, not as a question to answer now. Keep the full
  ids it names.
- **A line that already starts with `Partner item: `** stays as it is,
  with its suffix.
- **A line that repeats a partner item already in the list:** drop it.
  A rebuild after a discard writes such a line again. Do not give it the
  prefix a second time.
- **Any other line** stays as it is, for step 2.

Write the list back whole with
`record.py set-closing-key REC ID unfinished replace`.

### 1a. Revise `learned`

Read the `learned` of every done phase
(`record.py get REC <phase id> closing.learned`). For each line:

- **Drop it** if one of these is true:
  - It is used up: the phase it was for is done and took it.
  - It is stale against `base`: a name it states is gone, or a claim no
    longer holds.
  - It repeats another line or a committed doc.
  - It repeats the project's instructions or a gate, or it is
    bookkeeping (step 1).
- **Correct it** if you know the correction, for example a rename that
  `base` shows.
- **Else, keep it.**

Write the changes to each list that changed with
`record.py set-closing-key REC <phase id> learned edit`: `drop` holds each
line to drop, and `edit` each correction as `[old, new]`. Copy each old
line exactly from the `get` output. Do not touch partner items here. They live in `unfinished`, and only your human
partner changes them.

Revise the effort's `learned` the same way. Read it with
`record.py get-effort REC learned`. Drop and correct by the same rules,
except that a line is used up only when every phase is done or dropped.
Write the changes with `record.py set-effort-key REC learned edit`.

## 2. Re-plan the phases that are not done

Go through every phase that is not `done` or `dropped`, other than this
one, with what this phase learned. For each change that this causes,
apply the **intent test**. Does the change alter one of these?

- the umbrella's goals, non-goals or anti-goals;
- a phase's purpose or limits in the Phases section;
- an answer your human partner gave;
- which phases exist, in a way that changes the outcome.

**No: rule on it yourself, and apply it.** That covers:

- **Answered `waits_on`:** if every `waits_on` of a `waiting` phase is
  answered (each `from` is this phase or a closed one), `set` its
  `status` to `known`. Leave its `waits_on` in place, because its Design
  stage reads the answers through them.
- **A new order, a split, a merge, or a drop that keeps the outcome:**
  follow the rules under `set-phases` in `references/record.md`. Then
  commit the umbrella's Phases section to match, on `base`. Split parts
  get their own entries (`### K2a: …`). In a close, this phase counts as
  closed for the `status` of a new phase.
- **The technical design of a phase:** the umbrella holds intent only.
  Never put a technical change into it. Put the change in the first
  place that applies:
  1. If the phase has a `plan`, put the change in its plan file, and in
     its own design file if it has one. Commit on `base`. The plan's task
     ids are already issued: add or split a task as the Ids section of
     `writing-plans` says (`#### Task K3.4a: …` for a part).
  2. Else, if the phase's `spec` is its own design file, put the change
     in that file. Commit on `base`.
  3. Else (`spec` null, or the umbrella), the phase has no file of its
     own. Add the change to this phase's `learned`, as a line that names
     that phase. Its Design stage reads `learned`. If its `spec` is the
     umbrella, `set` it to null so that its Design stage runs. Write the
     line now with `record.py set-closing-key`, key `learned`, mode
     `append`, so that the `replan` write keeps it.
- **Each unfinished finding that is not a partner item:** move it to the
  phase it belongs to, the same way as a technical design change. Name
  the id it came from (`from K2: Task K2.3: …`). The moved text lives
  only at its destination. Its line in `unfinished` keeps only the
  pointer: the id and the phase it went to (`Task K2.3: moved to K3`).
  Read the list with `record.py get REC ID closing.unfinished`. Write each
  moved line and its pointer as 1 `[old, new]` pair, with
  `record.py set-closing-key REC ID unfinished edit`.

**Yes: do not rule.** The change is a partner item. So is each open
partner-item line that step 1 wrote. Its interim default decides where
it goes:

- **The interim default** is what later stages do until your human
  partner answers. It is the option that commits to nothing new and can
  be reversed, usually the status quo. Never choose among the options: a
  default picked by preference settles the item.
- **An item is blocking if no such default exists:** a phase that is not
  done cannot be designed until your human partner answers the item.
  Only a blocking item goes to `partner_questions`, as below.
- **A non-blocking item is a partner-item line in this phase's
  `unfinished`,** with its default. If the item is a change that this
  re-plan found, write its line as step 1 says
  (`record.py set-closing-key REC ID unfinished append`). It goes to no
  `partner_questions`, and no phase's `status` changes for it. Later
  stages follow its default. Your human partner settles it at the end of
  the effort.
- **If this re-plan drops a phase, each blocking question of that phase
  becomes a partner-item line in this phase's `unfinished`.** Then the
  drop does not lose it. A question that came from a partner-item line
  gets no new line: that line ends in
  `→ partner_questions of <the dropped id>`. In the array that you give
  to `record.py set-phases` for the drop, take that
  pointer off the line, with the space before it. The item is open
  again, and it blocks nothing.

For a blocking item:

1. Read the blocked phase's list with
   `record.py get REC <phase id> partner_questions`.
2. `record.py set` the list with the question added.
3. `record.py set` the blocked phase's `status` to `needs-partner`. A
   waiting phase whose answer raised the question also goes to
   `needs-partner`, not `known`.
4. If the question came from a partner-item line, add
   `→ partner_questions of <phase id>` at the end of that line, with
   `record.py set-closing-key REC ID unfinished edit`.

Write the question so that a reader who did not see this session can
understand it alone. It states:

- what this phase learned;
- the intent decision that it conflicts with;
- the ways your human partner can answer.

Put the ways to answer before the question itself, so that the question
mark is the last character. Do not edit the umbrella for the question.
Your human partner's answer does that, in the intent round of the phase.

**When in doubt, automate:** rule on it, and mark it `borderline`.

**Write `replan` last.** It marks the phase closed. It holds an entry for
each change, and for each question:

```json
{ "intent": false, "borderline": false, "change": "...", "affects": ["K3"], "why": "...", "alternative": "..." }
```

- `intent`: true for a question to your human partner. `change` is then
  what was proposed, not applied.
- `alternative`: the option you did not take. For a question, it is the
  other answer your human partner can give.

A non-blocking partner item is not a change, and gets no entry. Its only
copy is its line in `unfinished`.

If there is no change, `replan` is `[]`. Write `replan` with
`record.py set-closing-key REC ID replan replace`.

## 3. Report

In this order:

1. **The borderline rulings,** each with its alternative.
2. **The questions for your human partner,** and the phase that waits on
   each. Then give the line below. `<n>` is the number of open partner
   items that this close wrote. `<m>` is the number of open partner items
   of all phases. Count only the lines
   with no `→ partner_questions of` pointer. A line with a pointer is a
   question above, and a phase waits on it. The `Open for you` line asks
   nothing:

   ```
   Open for you: <n> new items (<m> in all). They wait for the end of the effort; nothing waits on them.
   ```

   If `<n>` is 1, write `1 new item`. If `<m>` is 1, write
   `1 in all). It waits for the end of the effort; nothing waits on it.`

3. **The other rulings.**
4. **What the next session will do:** first the missed git ops of this
   phase, if it is not merged. Then the next phase, and the stage it
   starts at (an intent round for a `needs-partner` phase). Run `pick` to
   find it. If `pick` prints `items` or `none`, every phase is done or
   dropped. Then run `## 5. The end of the effort` of
   `references/resume.md`, in this session.

## 4. The ending

- **In the plan's own session:** ask your human partner to clear the
  session and invoke the skill in a new one (for example: "Use
  superpowers-extended-cc:chaining-plans to continue the effort."). Do not
  start another phase in this session. If item 4 ran the end of the
  effort, its end round or its last message replaces the request to
  clear. This session then takes your human partner's answers as that
  section says. An answer that adds a phase ends with the request to
  clear, not with a pick.
- **From Resume's settle step:** leave out item 4 of the report. Do not
  ask for a clear. Go back to Resume's settle step, and continue with the
  action of the row. For a `finished-unclosed` phase, its missed git ops
  come next. Then Resume runs `phase-state`, settles the rest, and picks,
  in this session. Resume's own pick reaches the end of the effort.
