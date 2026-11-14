# The record and its commands

The record is the machine state of one effort: one JSON file per effort,
at `<main checkout>/.superpowers/chain/<id>/effort.json`. `<id>` is the
umbrella's spec letter (`K`, from its first line `# K: …`). `.superpowers/` is git-ignored, so the
record is never committed. It is kept after the effort is done.

Update it in place with the commands below, never by hand-editing and
never by rewriting the whole file from memory. It keeps no history.

## Shape

```json
{
  "umbrella": "docs/superpowers/specs/K.md",
  "base": "main",
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
      "branch": null,
      "closing": null
    }
  ]
}
```

There is no `head` key and no stored "done".

## Fields

- `umbrella`: path of the umbrella spec, relative to the repo root.
- `base`: the branch every phase merges into.
- `phases`: **the array order is the order of work.**
- `id`, `title`: the phase's name.
- `status` holds only what cannot be read from elsewhere:
  - `known`: ready to design;
  - `waiting`: on its `waits_on`;
  - `needs-partner`: has intent questions in `partner_questions`;
  - `dropped`.
- `depends_on`: ids of phases whose code this phase builds on (build order).
- `waits_on`: each entry names a question and the phase (`from`) whose plan
  must answer it (knowledge order).
- `partner_questions`: intent questions for the human partner.
- `spec`, `plan`, `branch`: links, filled in as the work creates them.
  `spec` and `plan` are repo-relative paths; `branch` is a branch name.
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

  `rulings` and `unfinished` fill in as each stage ends, so the close does
  not depend on context surviving compaction. `learned` and `replan` stay
  null until the close; `replan` set (even to `[]`) means the phase is
  closed.

## Phase states

`phase-state` prints exactly one of these, from the first rule that fits:

| State | Meaning |
|---|---|
| `dropped` | `status` is `dropped` |
| `not-started` | `branch` is null |
| `cut-off` | the branch's SDD workspace exists: a directory under `<w>/.superpowers/sdd/` whose `plan-path` file holds the phase's `plan`. `<w>` is the worktree that has the branch checked out, else the main checkout. A null `plan` finds no workspace |
| `close-missed` | merged, `closing.replan` null |
| `done` | merged, `closing.replan` set |
| `finished-unclosed` | not merged, `closing.replan` null |
| `closed-unmerged` | not merged, `closing.replan` set |

Merged means the branch is missing, or is an ancestor of `base`, or `gh pr
view` says `MERGED` (gh runs only when both git checks fail, stderr
discarded). A branch deleted without a merge, such as a discard whose
reset to null was missed, also reads as merged; the close finds no work
of it on `base` and stops (`close.md` step 1).

## Commands

Every command is a subcommand of one script, `scripts/record.py`, in this
skill's base directory (the installed plugin, not the project). Run it by
its absolute path, one plain command per Bash call:

```
python3 <this skill's base directory>/scripts/record.py <subcommand> <arguments>
```

Below, `record.py <subcommand>` is short for that whole line.

- **Write every value literally** on the command line: no variable
  assignments, no `&&` or `;`, no `$(…)`, no heredoc. Claude Code refuses
  compound commands from inside a worktree it isolates; one plain command
  runs anywhere.
- **`REC` is the absolute path of the effort's `effort.json`, and `ID` a
  phase id.** Both are copied, never shortened.
- **A JSON value** goes in `--value '<json>'` when it is short and holds
  no single quote (`--value '"worktree-K2"'`, `--value '[]'`). Otherwise,
  write it with the Write tool to a file under `.superpowers/tmp/` of the
  working tree you are in, and pass `--value-file <that path>`. Inside a
  worktree the Write tool cannot write into the main checkout, where the
  record lives, so a value file never goes beside the record.
- **Read the record through the script,** with `get` and `questions`, or
  with the Read tool. Every write reads the record fresh, so nothing is
  composed from memory.
- **A command that cannot do its job** says why on stderr
  (`record <subcommand>: <reason>`), exits 1, and changes nothing. A usage
  mistake exits 2. Every write goes through `<REC>.tmp` and an atomic
  rename. The script runs git read-only and writes only the record.

### chain-dir

`record.py chain-dir`

Prints the absolute `<main checkout>/.superpowers/chain`, the same from
any worktree. Outside a git repo it prints nothing and fails.

### open-efforts

`record.py open-efforts [--chain-dir DIR]`

Prints one `effort.json` path per line, for each effort with at least one
phase that is not `done` or `dropped`. Without `--chain-dir` it finds the
directory as `chain-dir` does; outside a git repo it then prints nothing
and fails. A record it cannot read is skipped, with a note on stderr.

### phase-state

`record.py phase-state REC ID`

Prints one state from the table above. It refuses an id the record does
not have.

### pick

`record.py pick REC`

Prints `id:<phase id>` for the first phase, in array order, that is
`not-started` and whose `depends_on` are all `done`. Otherwise prints
`blocked:<phase id>` for the first phase that is not `done` or `dropped`
(it waits on a dependency that is not done, or is dropped, or is itself
under way), or `none` when every phase is `done` or `dropped`.

### get

`record.py get REC ID [FIELD]`

Prints the phase, or one of its fields, as compact JSON:
`record.py get REC K3 closing`. It refuses an unknown id or field.

### questions

`record.py questions REC ID`

Prints, as compact JSON, the `waits_on` questions that phase `ID` must
answer, gathered from every phase of the record, each with the phase that
asks it: `[{"phase":"K3","q":["…"]}]`, or `[]`.

### new-record

`record.py new-record REC --value-file <path>`

Create's one write: it creates `REC` and its directory from the whole
record in the value file, in the shape above. It fails, and writes
nothing, when `REC` already exists, or the record lacks `umbrella` or
`base`, or a phase lacks one of the ten keys, has one more, or repeats an
id.

### set

`record.py set REC ID FIELD (--value <json> | --value-file <path>)`

Sets that field of the phase to the JSON value, in place:
`record.py set REC K2 branch --value '"worktree-K2"'`. It fails, and
writes nothing, when the record has no phase `ID` with that field, or the
value is not JSON. A change to `closing` goes through `set-closing-key`.

### set-closing-key

`record.py set-closing-key REC ID KEY MODE (--value <json> | --value-file <path>)`

Sets one key of the phase's `closing`, and keeps every other key as read.
`KEY` is `rulings`, `unfinished`, `learned` or `replan`, and the value is
a JSON list. `MODE` is `append`, which adds the list's items after the
key's own (a null key counts as empty), or `replace`, which sets the key
to the list. A null `closing` starts as
`{"rulings": [], "unfinished": [], "learned": null, "replan": null}`.
`replan` is written whole, with `replace`, and never back to null:
setting it marks the phase closed. It fails, and writes nothing, for an
unknown id or key, a value that is not a list, or `append` to `replan`.

### set-phases

`record.py set-phases REC --value-file <path>`

Replaces `phases` with the JSON array of whole phases in the value file,
in place, and leaves `umbrella` and `base` alone. It fails, and writes
nothing, unless every phase has exactly the ten keys of the shape above
and no id repeats. For a split, merge, reorder or drop: read the record
fresh with the Read tool, write the new array to a value file, and pass
it to `record.py set-phases` with `--value-file`; never build it from
memory.

These rules hold for every split, merge, reorder or drop, from a close or
from Resume's Plan stage:

- **Only a phase whose `branch` is null** is split, merged or dropped.
- **The array order is the order of work:** each phase after every phase
  it depends on or waits on.
- **A split:** every part gets the split phase's id plus one lowercase
  letter, in work order (K2 splits into `K2a`, `K2b`, …, skipping i, l
  and o); none keeps the bare id, which still names the whole. A part
  that splits again alternates to a number (`K2a` into `K2a1`, `K2a2`).
  The first part takes the split phase's `spec` and `closing`. Every
  other part is a new phase with all ten keys, the split phase's `spec`
  (its design, or the
  umbrella, covers every part, and each part's plan says which part it
  builds), and null `plan`, `branch` and `closing`. Every part, the
  first included, has a null `plan`: a plan for the whole phase is not a
  plan for a part. Each part gets the `depends_on`, `waits_on` and
  `partner_questions` that concern it, and a later part that builds on
  an earlier part's code depends on it.
- **A merge:** the merged phase keeps the id of the first of them, in
  array order; the others leave the record, and their ids are never
  issued again. Its Phases entry gets a line `**Merged from:** K5`,
  naming each id it absorbed. It joins their `depends_on`, `waits_on` and
  `partner_questions`, without its own id. Its `spec` and `plan` are
  null, so its Design stage writes one design for the whole. Its
  `closing` is null when all of theirs are; else it joins their
  `rulings` and `unfinished`, with `learned` and `replan` null. Merges
  happen only in a close: name any design file the merged phases had in
  a line of the closing phase's `learned` that names the merged phase,
  and write that line at once with `record.py set-closing-key`, the
  closing phase's id, key `learned`, mode `append`, as `close.md` step 2
  does for a design change.
- **The `status` of every part of a split, the first included, and of a
  merged phase:** `needs-partner` if it has `partner_questions`, else
  `waiting` if any of its `waits_on` has a `from` that is not closed
  yet, else `known`. A part that inherits only answered `waits_on` is
  `known`.
- **Every other phase:** a `depends_on` on a split id is replaced by
  every part; a `waits_on` that a part will answer gets that part as its
  `from`. A merged id is replaced by the merged phase's id, once.
- **A drop:** the phase stays in the array with `status` `dropped`, and
  its id is never issued again. Take
  its id out of every other phase's `depends_on` and `waits_on`.
- **Every `waits_on[].from` is also in that phase's `depends_on`.** A
  change that adds or moves a `waits_on` adds its `from` there too.
- **Make the umbrella's Phases section match,** committed on `base` in
  the main checkout: one entry per phase, under its id, in array order.
  New entries carry the old entries' words, divided or joined, with
  nothing added, and their "Depends on" and "Waits on" lines match the
  record.
