# Chaining Plans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `chaining-plans` skill, a rail that carries one effort
from plan to plan with an intent sitting at the split, a fresh session per
plan, and a close that re-plans the later phases.

**Architecture:**
- `SKILL.md` holds the always-needed rules: the standing approval,
  routing to the three entry points, the "invoke, don't recall" rules,
  and the Red Flags.
- Each entry point lives in its own reference file, read fresh at the
  step that needs it: `create.md`, `resume.md`, `close.md`.
- `record.md` holds the record's shape and every shell command the agent
  runs against it. Each command is a named fenced block, so a test can
  pull it out and run it.
- No scripts ship.
- No existing skill changes.

**Tech Stack:** Markdown skill files, bash, `jq`, `git`, `gh`; tests in
bash, with headless `claude -p` for the behavior tests.

**Spec:** `docs/superpowers/specs/2026-11-12-chaining-plans-design.md`

## Global Constraints

- No file under `skills/` other than `skills/chaining-plans/**` changes.
- No script ships in `skills/chaining-plans/`. Commands live in
  `references/record.md` as named blocks.
- `skills/chaining-plans/SKILL.md` stays under 20000 bytes
  (`tests/skill-size/test-skill-size.sh`).
- No `test-*.md` or `CREATION-LOG.md` under `skills/`
  (`tests/skill-layout/test-no-dev-files-in-skills.sh`).
- The record lives at
  `<main checkout>/.superpowers/chain/<id>/effort.json`. The main
  checkout is the parent of
  `git rev-parse --path-format=absolute --git-common-dir`. `<id>` is the
  umbrella spec's basename without `.md`.
- The record is one JSON object with the keys of the spec's Shape:
  `umbrella`, `base`, and `phases[]`. Each phase has `id`, `title`,
  `status`, `depends_on`, `waits_on`, `partner_questions`, `spec`,
  `plan`, `branch`, `closing`. There is no `head` key.
- Phase `status` values are exactly: `known`, `waiting`, `needs-partner`,
  `dropped`.
- `closing` keys are exactly: `rulings`, `unfinished`, `learned`,
  `replan`. Each `replan` item has `intent`, `borderline`, `change`,
  `affects`, `why`, `alternative`.
- Updates are in place: `jq … "$rec" > "$rec.tmp" && mv "$rec.tmp"
  "$rec"`.
- The skill does not set `disable-model-invocation`, because the close is
  the skill invoking itself.
- **Voice:** "your human partner", as in every superpowers skill.
- **"git ops"** means: option 1 (merge locally), push `base`, delete the
  remote branch if it exists. If the branch has an open PR, it means
  merging that PR instead.
- The skill is written by hand, not with `writing-skills`.

## Review Focus

1. **Two or more unfinished efforts, and no id given.** Resume must ask
   which effort; it must not pick one. Test: Task 1, `open-efforts`
   returns both.
2. **A session started inside a worktree.** `chain-dir` must still
   resolve to the main checkout. Test: Task 1, run from a linked
   worktree.
3. **A missed git ops whose push fails** (no remote). Resume stops and
   leaves the branch and the worktree in place. Test: Task 3, the
   no-remote fixture.
4. **A project that builds in place, with no worktree.** `phase-state`
   must find the SDD workspace in the main checkout. Test: Task 1, the
   in-place cut-off fixture.
5. **A phase whose `depends_on` names a dropped phase.** It is blocked.
   Resume reports the inconsistency and does not start it. Test: Task 1,
   `pick` returns `blocked:<id>`.

---

### Task 1: The record and its commands

**Files:**
- Create: `skills/chaining-plans/references/record.md`
- Create: `tests/chaining-plans/test-record-commands.sh`

**Interfaces:**
- Produces named command blocks in `record.md`. Each block is introduced
  by a line `<!-- cmd: NAME -->` directly above a ```` ```bash ```` fence.
  Each reads only the variables listed and prints only what is listed:
  - `chain-dir` — reads nothing; sets and prints `chain_dir`, the
    absolute `<main checkout>/.superpowers/chain`.
  - `open-efforts` — reads `chain_dir`; prints one `effort.json` path per
    line, for each effort with at least one phase whose `phase-state` is
    not `done` or `dropped`.
  - `phase-state` — reads `rec` (path to `effort.json`) and `id`; prints
    exactly one of: `dropped`, `not-started`, `cut-off`,
    `finished-unclosed`, `closed-unmerged`, `close-missed`, `done`.
  - `pick` — reads `rec`; prints `id:<phase id>` for the first phase, in
    array order, whose state is `not-started` and whose `depends_on` are
    all `done`. Otherwise it prints:
    - `blocked:<phase id>`, when the first remaining phase depends on a
      phase that is not done, or that is `dropped`;
    - `none`, when every phase is `done` or `dropped`.
  - `set` — reads `rec`, `id`, `field` and `value_json`; sets
    `.phases[] | select(.id == $id) | .[$field]` to the JSON value, in
    place.
- **`phase-state` rules**, applied in this order:
  1. `status == "dropped"` → `dropped`.
  2. `branch` is null → `not-started`.
  3. The branch's SDD workspace exists → `cut-off`. The workspace is a
     directory under `<w>/.superpowers/sdd/` whose `plan-path` file holds
     the phase's `plan`. `<w>` is the worktree that has the branch checked
     out (`git worktree list --porcelain`), else the main checkout.
  4. Merged means one of:
     - the branch is missing (`git rev-parse -q --verify refs/heads/<b>`
       fails);
     - `git merge-base --is-ancestor <b> <base>`;
     - `gh pr view <b> --json state -q .state` prints `MERGED`. Run gh
       only if both git checks fail, with its stderr discarded.
  5. Merged and `closing.replan` null → `close-missed`. Merged and set →
     `done`.
  6. Not merged and `closing.replan` null → `finished-unclosed`. Not
     merged and set → `closed-unmerged`.
- `record.md` also documents:
  - the record's shape, as the spec's Shape section gives it;
  - the meaning of each field;
  - that `rulings` and `unfinished` fill in as each stage ends.

- [ ] **Step 1: Write the failing test**

  The test builds fixtures in `mktemp -d` git repos. Each repo has a
  `main` branch and a committed `docs/superpowers/plans/p.md`. The test
  extracts each command block by name from `record.md` (the lines
  between the marker's fence and the closing fence), then `eval`s it
  with the inputs set. It counts failures and exits 1 on any.

  Assertions:
  - `chain-dir`, run in the main checkout, prints `<repo>/.superpowers/chain`.
  - `chain-dir`, run in a linked worktree of the same repo, prints the
    same path (Review Focus 2).
  - `phase-state` gives one state per fixture:
    - `dropped`: status dropped;
    - `not-started`: `branch` null;
    - `cut-off` with a worktree: the branch is in a linked worktree with
      `.superpowers/sdd/p/plan-path` containing `docs/superpowers/plans/p.md`;
    - `cut-off` in place: the same workspace in the main checkout, with
      the branch checked out there (Review Focus 4);
    - `finished-unclosed`: the branch has one commit not on main, no
      workspace, and `closing.replan` null;
    - `closed-unmerged`: the same, with `closing.replan` set to `[]`;
    - `close-missed`: the branch was merged into main and deleted, with
      `closing.replan` null;
    - `done`: the same, with `closing.replan` set to `[]`.
  - `pick`, on `[p1 done, p2 not-started depends_on p1]`, prints `id:p2`.
  - `pick`, on `[p1 dropped, p2 not-started depends_on p1]`, prints
    `blocked:p2` (Review Focus 5).
  - `pick`, on `[p1 done]`, prints `none`.
  - `open-efforts`, with two efforts each holding a `not-started` phase
    and one effort with all phases `done`, prints exactly the first two
    (Review Focus 1).
  - `set` with `field=branch value_json='"p2"'` changes only that phase.
    `jq -e .` on the file passes, and no `.tmp` file is left.

- [ ] **Step 2: Run it to see it fail**

  Run: `bash tests/chaining-plans/test-record-commands.sh`

  Expected: FAIL, because `record.md` does not exist.

- [ ] **Step 3: Write `skills/chaining-plans/references/record.md`**

  It contains the shape, the field meanings, and the five named blocks,
  per Interfaces. The commands use only `git`, `jq`, `gh` and POSIX
  tools.

- [ ] **Step 4: Run the test to see it pass**

  Run: `bash tests/chaining-plans/test-record-commands.sh`

  Expected: every line `[PASS]`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/chaining-plans/references/record.md tests/chaining-plans/test-record-commands.sh
git commit -m "feat(chaining-plans): the record and its tested commands"
```

### Task 2: The skill's core and Create

**Files:**
- Create: `skills/chaining-plans/SKILL.md`
- Create: `skills/chaining-plans/references/create.md`
- Create: `tests/claude-code/test-chaining-plans-create.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (add the new test to
  `integration_tests`)
- Modify: `README.md` ("Skills Library" → Collaboration: one line for
  `chaining-plans`)

**Interfaces:**
- Consumes: the command names from Task 1. `SKILL.md` and `create.md`
  refer to them by name ("run `chain-dir` from references/record.md"),
  never by copying them.
- Produces: the routing by arguments. Tasks 3 and 4 rely on these exact
  forms:
  - `create [<spec path>]` → read `references/create.md`;
  - no arguments, or an effort id → read `references/resume.md`;
  - `close <effort id> <phase id>` → read `references/close.md`.
- **`SKILL.md` frontmatter:**
  - `name: chaining-plans`
  - `description: Use when your human partner asks to chain a spec that needs several plans, to continue the next plan of an effort, or when closing a plan of an effort after its merge menu`
- **`SKILL.md` sections**, from the spec:
  - Overview: the model, intent up front and technical design just in
    time.
  - The standing approval. It covers the phase design, `writing-plans`'
    plan-review wait, the execution method, the worktree consent of
    `using-git-worktrees`, and Resume's missed git ops. It cites "your
    human partner's instructions take precedence over skills".
  - Routing.
  - Where things live: the umbrella's Phases section, the phase designs,
    and the record.
  - Invoke, don't recall: the rules, plus a Red Flags table that has at
    least the spec's three rows.
- **`create.md`:** the spec's Create steps 1–5, and touchpoint 2 (plans
  already written: link one only to a phase with no `waits_on`; name the
  others in the hand-over). The Phases-section format gives each phase:
  - its id and title;
  - its purpose and limits;
  - the human partner's answers;
  - its `depends_on` and `waits_on`.

- [ ] **Step 1: Write the failing test**

  Model it on `test-subagent-driven-development-integration.sh`: a
  `mktemp` project, a `trap` cleanup, `claude -p … --plugin-dir
  "$PLUGIN_DIR" --permission-mode bypassPermissions`, `timeout 900`.

  **Fixture:** a git repo on `main`. It has a committed `.gitignore`
  listing `.superpowers/` and `.worktrees/`; every fixture in Tasks 2–4
  has the same `.gitignore`, so Resume's clean-tree check sees a clean
  tree. It also has a committed
  `docs/superpowers/specs/2026-01-01-notes-design.md`. It is an approved
  design for a notes CLI, with three parts the text orders:
  1. storage;
  2. search;
  3. export, whose format depends on what the search part learns about
     note size.

  **Prompt:** `Use the superpowers:chaining-plans skill to create an
  effort from docs/superpowers/specs/2026-01-01-notes-design.md.`

  **Assertions:**
  - The output names all three phases, storage before export.
  - It mentions what export waits on (`assert_contains` on
    `wait\|depends\|after`).
  - It contains a question mark.
  - `.superpowers/chain/2026-01-01-notes-design/effort.json` does not
    exist yet, because the sitting is unanswered.
  - There is no file under `docs/superpowers/plans/`.
  - `git rev-list --count main` is unchanged.
  - The skill size and skill layout tests pass.

- [ ] **Step 2: Run it to see it fail**

  Run: `bash tests/claude-code/test-chaining-plans-create.sh`

  Expected: FAIL, because the skill is not found and no phases are
  listed.

- [ ] **Step 3: Write `SKILL.md`, then `references/create.md`**

  Write them per Interfaces. Then add the README line, and register the
  test in `run-skill-tests.sh`'s `integration_tests`.

- [ ] **Step 4: Run the tests to see them pass**

  Run: `bash tests/claude-code/test-chaining-plans-create.sh && bash tests/skill-size/test-skill-size.sh && bash tests/skill-layout/test-no-dev-files-in-skills.sh`

  Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/chaining-plans/SKILL.md skills/chaining-plans/references/create.md tests/claude-code/test-chaining-plans-create.sh tests/claude-code/run-skill-tests.sh README.md
git commit -m "feat(chaining-plans): the skill's core and the intent sitting"
```

### Task 3: Resume

**Files:**
- Create: `skills/chaining-plans/references/resume.md`
- Create: `tests/claude-code/test-chaining-plans-resume.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (add it to
  `integration_tests`)

**Interfaces:**
- Consumes:
  - `chain-dir`, `open-efforts`, `phase-state`, `pick` and `set` (Task 1);
  - the routing forms, including `close <effort id> <phase id>` (Task 2).
- `resume.md` holds:
  - **Find the record.** Several open efforts and no id → ask.
  - **Check git:** the main checkout, a clean tree.
  - **Settle every phase** whose `phase-state` is `cut-off`,
    `finished-unclosed`, `closed-unmerged` or `close-missed`, in array
    order, per the spec's table:
    - `cut-off` → re-invoke the executor in that worktree;
    - `finished-unclosed` → close, then the missed git ops;
    - `closed-unmerged` → the missed git ops;
    - `close-missed` → close.
  - **The missed git ops:** per the spec's "Doing a missed `git ops`".
    Invoke `finishing-a-development-branch` fresh, from the branch's
    worktree, and answer its menu with git ops. Delete the remote branch
    only if `git ls-remote --heads origin <b>` lists it. Stop on any
    failed safeguard, and report each merge first.
  - **Pick**, with `pick`'s three outcomes:
    - `none` → report that the effort is done;
    - `blocked:<id>` → report what blocks it and stop.
  - **Where a phase design goes:**
    `docs/superpowers/specs/<date>-<umbrella topic>-<phase id>-design.md`,
    unless the umbrella already covers the phase. Then `spec` links the
    umbrella.
  - **The stage table**, with each stage's "Done when", from the spec.
  - **The touchpoint rules from the spec**, each one line at the stage it
    belongs to:
    1. No brainstorm for the phase design.
    2. The design's inputs: the whole umbrella, `closing.learned` of the
       done phases, and the code on `base`. The design copies the phase's
       Phases entry word for word.
    3. The builder-check prompt path, relative to the skill base
       directory.
    4. Commit the design and the plan on `base` before the build.
    5. A further split from `writing-plans` is a re-plan ruling.
    6. The worktree preference: a worktree, unless the project builds in
       place.
    7. Record `branch` as soon as it exists.
    8. Copy "Rulings I made" and "Unfinished" into `closing` between the
       executor's final message and finishing.
    9. Give finishing the record's `base`.
    10. After the menu, invoke the skill with
        `close <effort id> <phase id>`.

- [ ] **Step 1: Write the failing test**

  Model it as Task 2's test. Each fixture has a passing
  `package.json` / `node --test` suite, because finishing runs the
  suite. Three fixtures:

  **A. Missed git ops on the last phase.**
  - Setup:
    - a bare repo as `origin`, with `main` pushed;
    - `effort.json` with one phase `p1`, `branch: "p1"`, and
      `closing.replan: []`;
    - branch `p1` with one commit, in `.worktrees/p1`;
    - no SDD workspace.
  - Prompt: `Use the superpowers:chaining-plans skill to continue the effort.`
  - Assertions:
    - `git merge-base --is-ancestor <p1 tip> main`;
    - `git rev-parse -q --verify refs/heads/p1` fails;
    - `.worktrees/p1` is gone;
    - `git rev-parse main` equals `git rev-parse origin/main` after
      `git fetch`;
    - the output mentions the merge, and that the effort is done.

  **B. The push fails (Review Focus 3).**
  - Setup: as A, but with no `origin`.
  - Assertions:
    - `refs/heads/p1` still exists;
    - `.worktrees/p1` still exists;
    - the output mentions the push failure.

    `main` may hold the merge. Finishing merges before it pushes, so
    only the branch and the worktree must survive.

  **C. An inconsistent pick.**
  - Setup: one phase, `status: "waiting"`, `branch: null`, and
    `depends_on: []`.
  - Assertions:
    - the output names the inconsistency (`assert_contains` on
      `inconsistent\|waiting`);
    - no file is created under `docs/superpowers/specs/` or
      `docs/superpowers/plans/`;
    - no branch other than `main` exists.

- [ ] **Step 2: Run it to see it fail**

  Run: `bash tests/claude-code/test-chaining-plans-resume.sh`

  Expected: FAIL, because `resume.md` is missing and the skill routes to
  nothing.

- [ ] **Step 3: Write `skills/chaining-plans/references/resume.md`**

  Write it per Interfaces, then register the test.

- [ ] **Step 4: Run it to see it pass**

  Run: `bash tests/claude-code/test-chaining-plans-resume.sh`

  Expected: A, B and C all PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/chaining-plans/references/resume.md tests/claude-code/test-chaining-plans-resume.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(chaining-plans): resume, with the missed git ops"
```

### Task 4: Close

**Files:**
- Create: `skills/chaining-plans/references/close.md`
- Create: `tests/claude-code/test-chaining-plans-close.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` (add it to
  `integration_tests`)

**Interfaces:**
- Consumes: `chain-dir` and `set` (Task 1); the `close <effort id> <phase
  id>` routing (Task 2); the `close-missed` path of `resume.md` (Task 3).
- `close.md` holds the spec's Close:
  - **when it runs:** after options 1, 2 and 3; the discard reset
    (`branch` null, `status` `known`); and `git -C <main checkout>`;
  - **step 1, `learned`:** answer each `waits_on` whose `from` is this
    phase, and add the surprises. Check `rulings` and `unfinished`
    against the final message. In the `close-missed` path, reconstruct
    from the plan and the branch's commits;
  - **step 2, re-plan with the intent test:** its four questions; what
    "no" may change; that "yes" adds to `partner_questions` and sets
    `needs-partner`; and "when in doubt, automate", marked `borderline`;
  - **step 3, the report:** in its order, ending with "clear the session
    and invoke the skill".

- [ ] **Step 1: Write the failing test**

  Model it as Task 2's test.

  **Fixture:** a close missed, with an intent conflict.
  - The umbrella spec has the non-goal "No new runtime dependencies".
  - Phase `p1` is merged into `main` and its branch deleted. Its
    `closing` is `{rulings: [], unfinished: [], learned: null, replan:
    null}`. Its merged commit adds `FINDINGS.md`: "Export to PDF needs a
    third-party PDF library; the standard library cannot write PDF."
  - Phase `p2`, "Export to PDF", has `status: "waiting"`,
    `depends_on: ["p1"]`, and `waits_on: [{from: "p1", question: "Can
    PDF export be done with the standard library?"}]`.

  **Prompt:** `Use the superpowers:chaining-plans skill to continue the effort.`

  **Assertions:**
  - `jq -e '.phases[0].closing.learned | length > 0'`;
  - `jq -e '.phases[0].closing.replan != null'`;
  - `jq -r '.phases[1].status'` is `needs-partner`;
  - `jq -e '.phases[1].partner_questions | length > 0'`;
  - the output contains a question mark;
  - no file under `docs/superpowers/plans/`;
  - no branch other than `main`.

- [ ] **Step 2: Run it to see it fail**

  Run: `bash tests/claude-code/test-chaining-plans-close.sh`

  Expected: FAIL, because `close.md` is missing and `p1` is never
  closed.

- [ ] **Step 3: Write `skills/chaining-plans/references/close.md`**

  Write it per Interfaces, then register the test.

- [ ] **Step 4: Run all the chaining-plans tests to see them pass**

  Run: `bash tests/chaining-plans/test-record-commands.sh && bash tests/claude-code/test-chaining-plans-close.sh && bash tests/skill-size/test-skill-size.sh`

  Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/chaining-plans/references/close.md tests/claude-code/test-chaining-plans-close.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(chaining-plans): the close and the intent test"
```
