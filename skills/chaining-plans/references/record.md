# The record and its commands

The record is the machine state of one effort: one JSON file per effort,
at `<main checkout>/.superpowers/chain/<id>/effort.json`. `<id>` is the
umbrella's spec letter (`K`, from its first line `# K: …`). `.superpowers/` is git-ignored, so the
record is never committed. It is kept after the effort is done.

Update it in place with `jq`, never by hand-editing and never by
rewriting the whole file from memory. It keeps no history.

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

Each block is named by the comment above it. Run it as written. Every
Bash call starts a fresh shell, so assign the block's inputs (`rec`, `id`,
`field`, `value_json`, `phases_json`, `record_json`, `chain_dir`) on lines
in the same Bash call, before the block. Run every block from inside the
repo. The blocks that classify phases (`phase-state`, `pick`,
`open-efforts`) carry the same `phase_state` function. A block that
cannot do its job says why on stderr, exits non-zero, and changes nothing.

### chain-dir

Reads nothing. Sets and prints `chain_dir`, the absolute
`<main checkout>/.superpowers/chain`, the same from any worktree.
Outside a git repo it prints nothing and fails.

<!-- cmd: chain-dir -->
```bash
common=$(git rev-parse --path-format=absolute --git-common-dir) &&
  chain_dir="$(dirname "$common")/.superpowers/chain" &&
  echo "$chain_dir"
```

### open-efforts

Reads `chain_dir`; when it is unset, finds it as `chain-dir` does.
Prints one `effort.json` path per line, for each effort with at least
one phase that is not `done` or `dropped`. Outside a git repo it prints
nothing and fails.

<!-- cmd: open-efforts -->
```bash
[ -n "${chain_dir:-}" ] || { common=$(git rev-parse --path-format=absolute --git-common-dir) &&
  chain_dir="$(dirname "$common")/.superpowers/chain"; }
phase_state() (
  pid=$1
  base=$(jq -r '.base' "$rec")
  ph=$(jq -c --arg id "$pid" '.phases[] | select(.id == $id)' "$rec")
  [ "$(printf '%s' "$ph" | jq -r '.status')" = dropped ] && { echo dropped; return; }
  b=$(printf '%s' "$ph" | jq -r '.branch // empty')
  [ -z "$b" ] && { echo not-started; return; }
  plan=$(printf '%s' "$ph" | jq -r '.plan // empty')
  main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  w=$(git worktree list --porcelain | awk -v ref="branch refs/heads/$b" \
    '/^worktree /{p=substr($0,10)} $0==ref{print p; exit}')
  [ -z "$w" ] && w=$main
  if [ -n "$plan" ]; then
    for f in "$w"/.superpowers/sdd/*/plan-path; do
      [ -f "$f" ] && grep -Fxq -- "$plan" "$f" && { echo cut-off; return; }
    done
  fi
  merged=no
  if ! git rev-parse -q --verify "refs/heads/$b" >/dev/null; then merged=yes
  elif git merge-base --is-ancestor "$b" "$base"; then merged=yes
  elif [ "$(gh pr view "$b" --json state -q .state 2>/dev/null)" = MERGED ]; then merged=yes
  fi
  closed=$(printf '%s' "$ph" | jq -r 'if .closing.replan == null then "no" else "yes" end')
  case "$merged,$closed" in
    yes,no) echo close-missed ;;
    yes,yes) echo done ;;
    no,no) echo finished-unclosed ;;
    no,yes) echo closed-unmerged ;;
  esac
)
[ -n "${chain_dir:-}" ] && for rec in "$chain_dir"/*/effort.json; do
  [ -f "$rec" ] || continue
  for id in $(jq -r '.phases[].id' "$rec"); do
    case "$(phase_state "$id")" in
      done|dropped) ;;
      *) echo "$rec"; break ;;
    esac
  done
done
```

### phase-state

Reads `rec` (path to `effort.json`) and `id`. Prints one state from the
table above.

<!-- cmd: phase-state -->
```bash
phase_state() (
  pid=$1
  base=$(jq -r '.base' "$rec")
  ph=$(jq -c --arg id "$pid" '.phases[] | select(.id == $id)' "$rec")
  [ "$(printf '%s' "$ph" | jq -r '.status')" = dropped ] && { echo dropped; return; }
  b=$(printf '%s' "$ph" | jq -r '.branch // empty')
  [ -z "$b" ] && { echo not-started; return; }
  plan=$(printf '%s' "$ph" | jq -r '.plan // empty')
  main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  w=$(git worktree list --porcelain | awk -v ref="branch refs/heads/$b" \
    '/^worktree /{p=substr($0,10)} $0==ref{print p; exit}')
  [ -z "$w" ] && w=$main
  if [ -n "$plan" ]; then
    for f in "$w"/.superpowers/sdd/*/plan-path; do
      [ -f "$f" ] && grep -Fxq -- "$plan" "$f" && { echo cut-off; return; }
    done
  fi
  merged=no
  if ! git rev-parse -q --verify "refs/heads/$b" >/dev/null; then merged=yes
  elif git merge-base --is-ancestor "$b" "$base"; then merged=yes
  elif [ "$(gh pr view "$b" --json state -q .state 2>/dev/null)" = MERGED ]; then merged=yes
  fi
  closed=$(printf '%s' "$ph" | jq -r 'if .closing.replan == null then "no" else "yes" end')
  case "$merged,$closed" in
    yes,no) echo close-missed ;;
    yes,yes) echo done ;;
    no,no) echo finished-unclosed ;;
    no,yes) echo closed-unmerged ;;
  esac
)
phase_state "$id"
```

### pick

Reads `rec`. Prints `id:<phase id>` for the first phase, in array order,
that is `not-started` and whose `depends_on` are all `done`. Otherwise
prints `blocked:<phase id>` for the first phase that is not `done` or
`dropped` (it waits on a dependency that is not done, or is dropped, or
is itself under way), or `none` when every phase is `done` or `dropped`.

<!-- cmd: pick -->
```bash
phase_state() (
  pid=$1
  base=$(jq -r '.base' "$rec")
  ph=$(jq -c --arg id "$pid" '.phases[] | select(.id == $id)' "$rec")
  [ "$(printf '%s' "$ph" | jq -r '.status')" = dropped ] && { echo dropped; return; }
  b=$(printf '%s' "$ph" | jq -r '.branch // empty')
  [ -z "$b" ] && { echo not-started; return; }
  plan=$(printf '%s' "$ph" | jq -r '.plan // empty')
  main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  w=$(git worktree list --porcelain | awk -v ref="branch refs/heads/$b" \
    '/^worktree /{p=substr($0,10)} $0==ref{print p; exit}')
  [ -z "$w" ] && w=$main
  if [ -n "$plan" ]; then
    for f in "$w"/.superpowers/sdd/*/plan-path; do
      [ -f "$f" ] && grep -Fxq -- "$plan" "$f" && { echo cut-off; return; }
    done
  fi
  merged=no
  if ! git rev-parse -q --verify "refs/heads/$b" >/dev/null; then merged=yes
  elif git merge-base --is-ancestor "$b" "$base"; then merged=yes
  elif [ "$(gh pr view "$b" --json state -q .state 2>/dev/null)" = MERGED ]; then merged=yes
  fi
  closed=$(printf '%s' "$ph" | jq -r 'if .closing.replan == null then "no" else "yes" end')
  case "$merged,$closed" in
    yes,no) echo close-missed ;;
    yes,yes) echo done ;;
    no,no) echo finished-unclosed ;;
    no,yes) echo closed-unmerged ;;
  esac
)
ids=$(jq -r '.phases[].id' "$rec")
states=""
for p in $ids; do states="$states$p $(phase_state "$p")
"; done
first_open=""
picked=""
for p in $ids; do
  s=$(printf '%s' "$states" | awk -v p="$p" '$1 == p {print $2}')
  case "$s" in done|dropped) continue ;; esac
  [ -z "$first_open" ] && first_open=$p
  [ "$s" = not-started ] || continue
  ready=yes
  for d in $(jq -r --arg id "$p" '.phases[] | select(.id == $id) | .depends_on[]?' "$rec"); do
    printf '%s' "$states" | grep -Fxq "$d done" || { ready=no; break; }
  done
  [ "$ready" = yes ] && { picked=$p; break; }
done
if [ -n "$picked" ]; then echo "id:$picked"
elif [ -n "$first_open" ]; then echo "blocked:$first_open"
else echo none
fi
```

### new-record

Reads `rec` and `record_json`, the whole record in the shape above.
Create's one write: it creates `rec` and its directory. It fails, and
writes nothing, when `rec` already exists, or `record_json` lacks
`umbrella` or `base`, or a phase lacks one of the ten keys, has one more,
or repeats an id. Assign `record_json` in the same Bash call, from a
quoted heredoc or `jq -n`.

<!-- cmd: new-record -->
```bash
if [ -e "$rec" ]; then
  echo "new-record: $rec already exists" >&2; false
elif printf '%s' "$record_json" | jq -e '(.umbrella | type) == "string"
    and (.base | type) == "string" and (.phases | type) == "array"
    and all(.phases[]; type == "object" and (keys | sort) == ["branch","closing","depends_on",
      "id","partner_questions","plan","spec","status","title","waits_on"])
    and (.phases | map(.id) | unique | length) == (.phases | length)' >/dev/null; then
  mkdir -p "$(dirname "$rec")" && printf '%s\n' "$record_json" | jq . > "$rec.tmp" &&
    mv "$rec.tmp" "$rec" || { rm -f "$rec.tmp"; echo "new-record: nothing written" >&2; false; }
else
  echo "new-record: record_json is not a whole record of the shape above" >&2; false
fi
```

### set

Reads `rec`, `id`, `field` and `value_json`. Sets that field of the phase
to the JSON value, in place. Example: `field=branch value_json='"K2"'`.
It fails, and writes nothing, when the record has no phase `id` with
that field, or `value_json` is not JSON.

<!-- cmd: set -->
```bash
if jq -e --arg id "$id" --arg field "$field" \
    'any(.phases[]; .id == $id and has($field))' "$rec" >/dev/null; then
  jq --arg id "$id" --arg field "$field" --argjson v "$value_json" \
    '(.phases[] | select(.id == $id) | .[$field]) = $v' "$rec" > "$rec.tmp" &&
    mv "$rec.tmp" "$rec" || { rm -f "$rec.tmp"; echo "set: nothing written" >&2; false; }
else
  echo "set: no phase '$id' with a field '$field' in $rec" >&2; false
fi
```

### set-phases

Reads `rec` and `phases_json`, a JSON array of whole phases. Replaces
`phases` with it, in place, and leaves `umbrella` and `base` alone. It
fails, and writes nothing, unless every phase has exactly the ten keys of
the shape above and no id repeats. For
a split, merge, reorder or drop: build `phases_json` from the current
`.phases` with jq in the same Bash call, never from memory.

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
  and write that line at once with `set` (read `closing`, then `learned`
  plus the line), as `close.md` step 2 does for a design change.
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

<!-- cmd: set-phases -->
```bash
if printf '%s' "$phases_json" | jq -e 'type == "array"
    and all(.[]; type == "object" and (keys | sort) == ["branch","closing","depends_on",
      "id","partner_questions","plan","spec","status","title","waits_on"])
    and (map(.id) | unique | length) == length' >/dev/null; then
  jq --argjson v "$phases_json" '.phases = $v' "$rec" > "$rec.tmp" &&
    mv "$rec.tmp" "$rec" || { rm -f "$rec.tmp"; echo "set-phases: nothing written" >&2; false; }
else
  echo "set-phases: phases_json is not an array of whole phases with distinct ids" >&2; false
fi
```
