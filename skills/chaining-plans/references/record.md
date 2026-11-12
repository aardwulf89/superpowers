# The record and its commands

The record is the machine state of one effort: one JSON file per effort,
at `<main checkout>/.superpowers/chain/<id>/effort.json`. `<id>` is the
basename of the umbrella spec. `.superpowers/` is git-ignored, so the
record is never committed. It is kept after the effort is done.

Update it in place with `jq`, never by hand-editing and never by
rewriting the whole file from memory. It keeps no history.

## Shape

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
    { "intent": false, "borderline": false, "change": "...", "affects": ["p3-types"], "why": "...", "alternative": "..." }
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
discarded).

## Commands

Each block is named by the comment above it. Run it as written. Every Bash
call starts a fresh shell, so assign the block's inputs (`rec`, `id`,
`field`, `value_json`, `chain_dir`) on lines in the same Bash call, before
the block. Blocks
that classify phases (`phase-state`, `pick`, `open-efforts`) carry the same
`phase_state` function; run them from inside the repo.

### chain-dir

Reads nothing. Sets and prints `chain_dir`, the absolute
`<main checkout>/.superpowers/chain`, the same from any worktree.

<!-- cmd: chain-dir -->
```bash
chain_dir="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.superpowers/chain"
echo "$chain_dir"
```

### open-efforts

Reads `chain_dir` (defaults to the `chain-dir` value when unset). Prints one `effort.json` path per line, for each effort
with at least one phase that is not `done` or `dropped`.

<!-- cmd: open-efforts -->
```bash
chain_dir=${chain_dir:-$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.superpowers/chain}
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
for rec in "$chain_dir"/*/effort.json; do
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
for p in $ids; do
  s=$(printf '%s' "$states" | awk -v p="$p" '$1 == p {print $2}')
  case "$s" in done|dropped) continue ;; esac
  [ -z "$first_open" ] && first_open=$p
  [ "$s" = not-started ] || continue
  ready=yes
  for d in $(jq -r --arg id "$p" '.phases[] | select(.id == $id) | .depends_on[]?' "$rec"); do
    printf '%s' "$states" | grep -Fxq "$d done" || { ready=no; break; }
  done
  [ "$ready" = yes ] && { echo "id:$p"; first_open=picked; break; }
done
case "$first_open" in
  picked) ;;
  "") echo none ;;
  *) echo "blocked:$first_open" ;;
esac
```

### set

Reads `rec`, `id`, `field` and `value_json`. Sets that field of the phase
to the JSON value, in place. Example: `field=branch value_json='"p2-x"'`.

<!-- cmd: set -->
```bash
jq --arg id "$id" --arg field "$field" --argjson v "$value_json" \
  '(.phases[] | select(.id == $id) | .[$field]) = $v' "$rec" > "$rec.tmp" && mv "$rec.tmp" "$rec"
```
