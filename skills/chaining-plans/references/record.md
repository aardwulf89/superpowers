# The record and its commands

The record is the machine state of one effort. It is one JSON file per
effort, at `docs/superpowers/efforts/<id>.json` of the main checkout,
committed on `base`. `<id>` is the umbrella's spec letter (`K`, from its
first line `# K: …`), and it is the effort id. Keep the record after the
effort is done.

Change the record in place with the commands below. Never edit it by hand,
and never rewrite the whole file from memory. Git holds its history.

**Make every write in the main checkout, on `base`, and commit it.**
- Almost every write comes with a docs commit that the chain makes anyway:
  Create's Phases section, the answers of an Intent round, a design, a plan,
  a close, the answers of an end round. Put the record in that commit.
- If a write has no docs commit of its own (a ruling logged as a stage
  ends), commit it alone at once, as `docs(<id>): record`. Then the tree
  stays clean for the next Resume.
- Never write the record from inside a phase's worktree. The build's
  results travel on the phase branch instead, in the build results file
  (Phase states).

## Shape

```json
{
  "umbrella": "docs/superpowers/specs/K.md",
  "base": "main",
  "learned": ["what the brainstorm found that every phase needs"],
  "phases": [
    {
      "id": "K2",
      "title": "Runtime libraries",
      "status": "waiting",
      "depends_on": ["K1"],
      "waits_on": [
        { "from": "K1", "question": "Which intrinsics differ from the reference in the executor's calibration?" }
      ],
      "partner_questions": [],
      "spec": null,
      "plan": null,
      "closing": null
    }
  ]
}
```

There is no `head` key, no `branch` key and no stored "done". The commands
read them from git (Phase states).

## Fields

- `umbrella`: the path of the umbrella spec, relative to the repo root.
- `base`: the branch every phase merges into.
- `learned`: null or a list of strings: what the brainstorm found that
  every phase needs (a map of the code, where the research lives, what was
  ruled out). Create seeds it. Each close revises it.
  A record without `learned` reads as null.
- `phases`: **the array order is the order of work.**
- `id`, `title`: the phase's name.
- `status` holds only what nothing else can show:
  - `known`: ready to design;
  - `waiting`: on its `waits_on`;
  - `needs-partner`: has intent questions in `partner_questions`;
  - `dropped`.
- `depends_on`: ids of phases whose code this phase builds on (build order).
- `waits_on`: each entry names a question and the phase (`from`) whose plan
  must answer it (knowledge order).
- `partner_questions`: intent questions for your human partner.
- `spec`, `plan`: links, as repo-relative paths. Each is set when the work
  creates the file it links.
- `closing`: null until the phase's first stage ends, then:

```json
{
  "rulings": ["every ruling of the phase's design, plan and build"],
  "unfinished": ["each 'Unfinished' line, with the phase it was moved to, or 'none' and why"],
  "learned": ["the answer to each waits_on question, then the surprises"],
  "replan": [
    { "intent": false, "borderline": false, "change": "...", "affects": ["K3"], "why": "...", "alternative": "..." }
  ]
}
```

  The Design and Plan stages write their `rulings` as they end, so the
  close does not depend on context that survives compaction. The Build
  stage's rulings and its unfinished lines arrive from `<phase id>.build.json` at the close.
  `learned` and `replan` stay null until the close. If `replan` is set
  (even to `[]`), the phase is closed.

  A partner-item line is an element of `unfinished` that starts with
  `Partner item: `. Its disposition is a suffix at the very end of the
  line: `[settled: <phase id>]`, `[dropped]`, `[carried]` or
  `[adopted by <phase id>]`. A line with none of them is open. Only your
  human partner gives a disposition.

## Phase states

The phase id names the phase's branch:
- `worktree-<phase id>` if Claude Code's `EnterWorktree` made it.
- `<phase id>` if the phase is built in place.

The build results file is `docs/superpowers/plans/<phase id>.build.json`.
Resume's Build stage commits it on the phase branch before finishing.
"Merged" means that this file reached `base`, by a merge, a fast-forward, a
squash or a rebase.

`phase-state` prints exactly 1 of these states, from the first rule that
fits:

| State | Meaning |
|---|---|
| `dropped` | `status` is `dropped` |
| `cut-off` | a build is under way: some working tree (`git worktree list`, the main checkout included) has a directory under `.superpowers/sdd/` whose `plan-path` file holds the phase's `plan`. A null `plan` finds no workspace |
| `done` | the build results file is on `base`, and `closing.replan` is set |
| `close-missed` | the build results file is on `base`, and `closing.replan` is null |
| `closed-unmerged` | the build results file is on the phase branch only, and `closing.replan` is set |
| `finished-unclosed` | the build results file is on the phase branch only, and `closing.replan` is null |
| `anomaly` | both branch names exist, or the phase branch has commits of its own but no workspace and no build results file. The cause is a session cut off after the executor deleted its workspace and before the results were committed (the build's rulings were lost with the workspace), or a change made by hand. Resume reports it and stops |
| `not-started` | none of the above: no branch, a branch with no commits of its own, or a branch deleted without its results reaching `base` (a discard) |

## Commands

Every command is a subcommand of 1 script, `scripts/record.py`, in this
skill's base directory (the installed plugin, not the project). Run it by
its absolute path, 1 plain command per Bash call:

```
python3 <this skill's base directory>/scripts/record.py <subcommand> <arguments>
```

Below, `record.py <subcommand>` is short for that whole line.

- **Write every value literally** on the command line. Use no variable
  assignments, no `&&` or `;`, no `$(…)` and no heredoc. Claude Code
  refuses compound commands from inside an isolated worktree. One plain
  command runs anywhere.
- **`REC` is the absolute path of the effort's record file, and `ID` is a
  phase id.** Copy both in full. Never shorten them.
- **Give a JSON value** in `--value '<json>'` if it is short and holds no
  single quote (`--value '"known"'`, `--value '[]'`). Otherwise:
  1. Write the value with the Write tool to a file under
     `.superpowers/tmp/` of the working tree you are in.
  2. Pass `--value-file <that path>`.

  Inside a worktree, the Write tool cannot write into the main checkout,
  where the record lives. So never put a value file beside the record.
- **Read the record through the script** (`get` and `questions`) or with
  the Read tool.
- **A command that cannot do its job** says why on stderr
  (`record <subcommand>: <reason>`), exits 1, and changes nothing. A usage
  mistake exits 2.

### open-efforts

`record.py open-efforts [--efforts-dir DIR]`

Prints 1 record path per line, for each effort that has either of these:
- at least 1 phase that is not `done` or `dropped`;
- an open partner item, when all its phases are `done` or `dropped`.

Without `--efforts-dir`, it reads the main checkout's
`docs/superpowers/efforts/`, the same from any worktree. Outside a git repo,
it then prints nothing and fails. It skips a record that it cannot read,
with a note on stderr.

### phase-state

`record.py phase-state REC ID`

Prints 1 state from the table above. It refuses:
- an id that the record does not have;
- a record whose `base` has no local branch. Every rule reads `base`, and
  without it a built phase reads `not-started`.

`pick` refuses the same. `open-efforts` skips such a record, with a note.

### pick

`record.py pick REC`

Prints `id:<phase id>` for the first phase, in array order, that is
`not-started` and whose `depends_on` are all `done`. Otherwise, it prints
`blocked:<phase id>` for the first phase that is not `done` or `dropped`.
That phase waits on a dependency that is not done, or is dropped, or is
itself under way. If every phase is `done` or `dropped`, it prints 1 of 2
ends:

- `items`: some partner item is open, in any phase, a dropped one included;
- `none`: no item is open. The effort is closed out, unless an item is
  `[carried]` (`resume.md` § 5).

### get

`record.py get REC ID [FIELD]`

Prints the phase, or 1 of its fields, as compact JSON:
`record.py get REC K3 status`. It refuses an unknown id or field.

FIELD can also be `closing.<key>`, for 1 key of `closing`:
`record.py get REC K3 closing.learned`. It prints `null` while `closing`
is null. It refuses a key that `closing` does not have. Read only the key
that a step uses: `rulings` is the largest key, and most steps do not use
it.

### get-effort

`record.py get-effort REC learned`

Prints the effort's `learned` as compact JSON, or `null` if it is null or
missing. It refuses any other key.

### questions

`record.py questions REC ID`

Prints, as compact JSON, the `waits_on` questions that phase `ID` must
answer. It gathers them from every phase of the record, each with the
phase that asks it: `[{"phase":"K3","q":["…"]}]`, or `[]`.

### carried

`record.py carried [--efforts-dir DIR]`

Prints, as compact JSON, 1 object per `[carried]` partner item, from every
record in the efforts directory, sorted by path:
`[{"record":"<path>","phase":"K2","index":1,"item":"Partner item: …"}]`,
or `[]`. `index` is the position in the phase's `closing.unfinished`.
Without `--efforts-dir`, it reads the main checkout's
`docs/superpowers/efforts/`. It skips a record that it cannot read, with a
note on stderr.

### new-record

`record.py new-record REC --value-file <path>`

Create's first write. It creates `REC` and its directory from the whole
record in the value file, in the shape above. It fails, and writes nothing,
if:
- `REC` already exists;
- the record lacks `umbrella` or `base`;
- `learned` is neither null nor a list of strings;
- a phase does not have exactly the nine keys, or 2 phases have the same id.

### set

`record.py set REC ID FIELD (--value <json> | --value-file <path>)`

Sets that field of the phase to the JSON value, in place:
`record.py set REC K2 status --value '"known"'`. It fails, and writes
nothing, if the record has no phase `ID` with that field, or the value is
not JSON. Change `closing` only with `set-closing-key`.

### set-closing-key

`record.py set-closing-key REC ID KEY MODE (--value <json> | --value-file <path>)`

Sets 1 key of the phase's `closing`, and keeps every other key as read.
- `KEY` is `rulings`, `unfinished`, `learned` or `replan`.
- `MODE` is `append`, `replace` or `edit`.
  - `append` adds the items of a JSON list after the key's own items (a
    null key counts as empty).
  - `replace` sets the key to a JSON list.
  - `edit` changes or drops lines of the key, each named by its exact
    text. Its value is an object with `edit`, `drop` or both:
    `{"edit": [["<old line>", "<new line>"]], "drop": ["<line>"]}`.
    The `edit` pairs apply first, then the drops. Each line takes the first
    equal line of the key that no earlier line took.

**Use `edit` to change a few lines** of a list: to drop a line, correct it,
or add a suffix at its end. Copy each old line exactly from a fresh
`record.py get REC ID closing.<key>`. If a line is not there, the command
refuses the whole edit, so a line from memory fails and changes nothing.
Use `replace` when most of the list changes.

A null `closing` starts as
`{"rulings": [], "unfinished": [], "learned": null, "replan": null}`.
Write `replan` whole, with `replace`, and never back to null: when you set
it, the phase is closed. The command fails, and writes nothing, for:
- an unknown id or key;
- for `append` or `replace`, a value that is not a list;
- for `edit`, a value of another shape, or a line that is not there;
- `append` or `edit` to `replan`.

### set-effort-key

`record.py set-effort-key REC learned MODE (--value <json> | --value-file <path>)`

Sets the effort's `learned`. `MODE`, the value and the exact-line rule
work as in `set-closing-key`. A null or missing `learned` counts as empty
for `append`. Read the current lines first with
`record.py get-effort REC learned`. The command fails, and writes nothing,
for:
- any key but `learned`;
- a value that is not a list of strings (`edit`: an object of the shape
  above);
- for `edit`, a line that is not there.

### set-phases

`record.py set-phases REC --value-file <path>`

Replaces `phases` with the JSON array of whole phases in the value file, in
place. It leaves `umbrella`, `base` and `learned` alone. It fails, and writes nothing,
unless every phase has exactly the nine keys of the shape above and no id
repeats. For a split, merge, reorder or drop:
1. Read the record fresh with the Read tool.
2. Write the new array to a value file.
3. Pass the file to `record.py set-phases` with `--value-file`.

Never build the array from memory.

These rules hold for every split, merge, reorder or drop, from a close or
from the Plan stage of Resume:

- **Split, merge or drop only a phase that is `not-started`**
  (`phase-state`).
- **The array order is the order of work:** each phase comes after every
  phase it depends on or waits on.
- **A split:**
  - Every part gets the split phase's id plus 1 lowercase letter, in work
    order. Skip the letters i, l and o. K2 splits into `K2a`, `K2b`, …. No part
    keeps the bare id, which still names the whole.
  - A part that splits again alternates to a number (`K2a` into `K2a1`,
    `K2a2`).
  - The first part takes the split phase's `spec` and `closing`.
  - Every other part is a new phase with all nine keys, the split phase's
    `spec` and a null `closing`. The split phase's design, or the umbrella,
    covers every part, and each part's plan says which part it builds.
  - Every part, the first included, has a null `plan`: a plan for the whole
    phase is not a plan for a part.
  - Each part gets the `depends_on`, `waits_on` and `partner_questions`
    that concern it.
  - If a later part builds on the code of an earlier part, the later part
    depends on it.
- **A merge:**
  - The merged phase keeps the id of the first of them, in array order. The
    others leave the record, and their ids are never issued again.
  - Its Phases entry gets a line `**Merged from:** K5`, naming each id it
    absorbed.
  - It joins their `depends_on`, `waits_on` and `partner_questions`,
    without its own id.
  - Its `spec` and `plan` are null, so its Design stage writes 1 design for
    the whole.
  - Its `closing` is null if all of theirs are null. Else it joins their
    `rulings` and `unfinished`, with `learned` and `replan` null.
  - Merges happen only in a close. Name any design file that the merged
    phases had, in a line of the closing phase's `learned` that names the
    merged phase. Write that line at once with `record.py set-closing-key`:
    the closing phase's id, key `learned`, mode `append`, as `close.md`
    step 2 does for a design change.
- **The `status` of every part of a split, the first included, and of a
  merged phase:** `needs-partner` if it has `partner_questions`, else
  `waiting` if any of its `waits_on` has a `from` that is not closed yet,
  else `known`. A part that inherits only answered `waits_on` is `known`.
- **Every other phase:**
  - Replace a `depends_on` on a split id with every part.
  - If a part will answer a `waits_on`, make that part its `from`.
  - Replace a merged id with the merged phase's id, once.
- **A pointer follows its question.** A partner-item line, in the
  `unfinished` of any phase, can end in `→ partner_questions of <id>`. If a
  split or a merge removes that id, put in its place the id of the phase
  that now holds the question. Write it in the array you pass to
  `record.py set-phases`.
- **A drop:** the phase stays in the array with `status` `dropped`, and its
  id is never issued again. Take its id out of the `depends_on` and
  `waits_on` of every other phase.
- **Every `waits_on[].from` is also in that phase's `depends_on`.** If a
  change adds or moves a `waits_on`, add its `from` there too.
- **Make the umbrella's Phases section match,** committed on `base` in the
  main checkout:
  - 1 entry per phase, under its id, in array order.
  - New entries carry the words of the old entries, divided or joined, with
    nothing added.
  - Their "Depends on" and "Waits on" lines match the record.
