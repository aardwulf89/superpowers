# Close: what the plan learned, and the re-plan

A close writes down what one phase's plan learned, re-plans the phases
that are not done, and reports. It is invoked as `close <effort id> <phase id>`,
from one of two places, and each has its own ending (step 4):

- **The plan's own session,** after its merge menu was answered.
- **Resume's settle step,** for a phase that is `finished-unclosed` or
  `close-missed`. That phase was built in an earlier session.

Every block named here is in `references/record.md`. Run it as written,
with its inputs assigned in the same Bash call.

## 0. Find the phase, and check the answer to the menu

- **Find the record:** run `chain-dir`; the record is
  `<chain_dir>/<effort id>/effort.json`. If it is missing, or has no
  phase with that id, say so and stop. Every later block gets
  `rec=<that path>` and `id=<phase id>`.
- **Work from the main checkout,** the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. After option 2
  or 3 the session may still be in the worktree, so run every git command
  as `git -C <main checkout>`. If the phase was built in place and its
  branch is still checked out there, switch to `base` before a commit and
  back after.
- **Read the current `closing`** with jq before you compose any
  `value_json` for it, every time, never from memory:
  `jq -c --arg id "$id" '.phases[] | select(.id == $id) | .closing' "$rec"`.
  A null `closing` starts as
  `{"rulings": [], "unfinished": [], "learned": null, "replan": null}`.
  Change only the keys a step names, and keep the rest as read.
- **`replan` already set:** the phase is closed. Say so, and go to the
  ending (step 4). Never set `replan` back to null.

**Which answer the menu got.** Invoked from Resume's settle step, there
was no menu in this session: run steps 1 to 4. In the plan's own session:

- **Option 1, 2 or 3:** run steps 1 to 4. After option 2 or 3 the branch
  is not merged yet; the next Resume does its missed git ops before
  anything new starts.
- **A discard:** no close. `set` the phase's `branch` to null and its
  `status` to `known`, report that, and stop. Your human partner is
  present, and directs what happens next.

## 1. Write `learned`

`learned` is what later phases need from this one. It holds, in order:

- **The answer to each `waits_on` question whose `from` is this phase,**
  in any phase of the record, each naming the phase that asked it:
  `jq -c --arg id "$id" '[.phases[] | {phase: .id, q: [.waits_on[]? | select(.from == $id) | .question]} | select(.q | length > 0)]' "$rec"`.
  Answer from what the plan found, not from what it set out to find. A
  question the plan did not answer gets that as its answer.
- **The surprises:** what the build found that its plan did not expect,
  and that a later phase's design should know.

**Check `rulings` and `unfinished` against the final message.** In the
plan's own session the executor's final message is still in view. Every
line of its "Rulings I made" must be in `rulings`, and every line of its
"Unfinished" in `unfinished`. Add any that are missing.

**From Resume's settle step,** that final message is gone. Reconstruct
`learned` from the plan (`plan`, when set) and the branch's commits: read
the plan, the commits' messages and their diffs, and any notes or findings files
they added.
- The branch exists: `git -C <main checkout> log -p <base>..<branch>`
  when it is not merged; when it is, the commits its merge brought in.
- The branch is gone: find its merge on `base`,
  `git -C <main checkout> log --merges --grep=<branch> <base>`, and read
  `<merge>^1..<merge>^2`. With no merge commit (a fast-forward or a
  squash), read the commits on `base` since the plan was committed.
- **None of its work is on `base`:** no merge names the branch, `gh pr
  view <branch> --json state -q .state 2>/dev/null` does not print
  `MERGED`, and no commit on `base` since the plan was committed does
  the plan's tasks. Then the branch was deleted without a merge, most
  likely a discard whose reset was missed. Stop, write nothing, and
  report that to your human partner. Never read unrelated commits as the
  branch's work.

Leave `rulings` and `unfinished` as they are: there is no final message
to check them against.

Write it with `set`: `field=closing`, `value_json` the closing you read,
with `learned` filled in and any missing lines added.

## 2. Re-plan the phases that are not done

Go through every phase that is not `done` or `dropped`, other than this
one, with what was learned. For each change it causes, apply the **intent
test**. Does the change alter any of these?

- the umbrella's goals, non-goals or anti-goals;
- a phase's purpose or limits in the Phases section;
- an answer your human partner gave;
- which phases exist, in a way that changes the outcome.

**No: rule on it yourself, and apply it.** That covers:

- **Resolving `waits_on`:** a `waiting` phase whose every `waits_on` is
  answered (each `from` is this phase or a closed one) becomes `known`,
  with `set`. Leave its `waits_on` in place: its Design stage reads the
  answers through them.
- **Reordering, a split, a merge, or a drop that keeps the outcome:**
  follow the rules under `set-phases` in `references/record.md`, and
  commit the umbrella's Phases section to match, on `base`. In a close,
  this phase counts as closed for a new phase's `status`.
- **A phase's technical design:** a phase with a design file (`spec`)
  gets the change in that file, committed on `base`. A phase with no
  design yet has no file: add the change to this phase's `learned` as a
  line naming that phase, since its Design stage reads `learned`. Write
  it now with `set` (read `closing`, then `learned` plus the line), so
  the `replan` write's fresh read keeps it.
- **Each unfinished finding:** move it to the phase it belongs to, the
  same way as a technical design change, and note that phase in its
  line in `unfinished`, with `set` the same way.

**Yes: do not rule.** Add the question to the affected phase's
`partner_questions` (read the list with jq, then `set` it with the
question added), and `set` its `status` to `needs-partner`. A waiting
phase whose answer raised the question goes to `needs-partner`, not
`known`. Word it as a question, ending in a question mark, that stands
on its own for a reader who did not see this session: what was learned,
which intent decision it conflicts with, and the ways your human partner
could answer. Do not edit the umbrella for it: your human partner's
answer does that, in the phase's intent round.

**When in doubt, automate:** rule on it, and mark it `borderline`.

**Write `replan` last.** It marks the phase closed. It holds one entry
per change, a question included:

```json
{ "intent": false, "borderline": false, "change": "...", "affects": ["p3-types"], "why": "...", "alternative": "..." }
```

- `intent`: true for a question to your human partner; `change` is then
  what was proposed, not applied.
- `alternative`: the option you did not take, or for a question, the
  other answer your human partner could give.

With no change at all, `replan` is `[]`. `set` it as the closing you
read, with `replan` filled in.

## 3. Report

In this order:

1. **The borderline rulings,** each with its alternative.
2. **The questions for your human partner,** and which phase waits on
   each.
3. **The other rulings.**
4. **What the next session will do:** the missed git ops of this phase
   if it is not merged, then the next phase and the stage it starts at
   (an intent round for a `needs-partner` phase). Or that the effort is
   done: run `pick`; it prints `none` when every phase is done or
   dropped.

## 4. The ending

- **In the plan's own session:** ask your human partner to clear the
  session and invoke the skill in a fresh one (for example: "Use
  superpowers:chaining-plans to continue the effort."). Do not start
  another phase in this session.
- **From Resume's settle step:** leave out item 4 of the report and do
  not ask for a clear. Go back to Resume's settle step and go on with
  the row's action: for a `finished-unclosed` phase, its missed git ops
  come next. Then Resume runs `phase-state`, settles the rest, and
  picks, in this session.
