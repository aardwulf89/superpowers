#!/usr/bin/env python3
"""The commands of a chaining-plans effort record.

The record of effort K is docs/superpowers/efforts/K.json, committed on base.
Run this script by its absolute path, one plain command per call:

    python3 <skill base>/scripts/record.py <subcommand> <args>

Subcommands:
    open-efforts [--efforts-dir DIR]
    phase-state REC ID
    pick REC
    get REC ID [FIELD | closing.KEY]
    questions REC ID
    carried [--efforts-dir DIR]
    new-record REC (--value JSON | --value-file PATH)
    get-effort REC KEY
    set REC ID FIELD (--value JSON | --value-file PATH)
    set-phases REC (--value JSON | --value-file PATH)
    set-closing-key REC ID KEY {replace,append,edit} (--value JSON | --value-file PATH)
    set-effort-key REC KEY {replace,append,edit} (--value JSON | --value-file PATH)

A refused command prints "record <subcommand>: <reason>" on stderr, exits 1,
and changes nothing. A usage error exits 2. Git runs read-only, in the current
directory; the only file this script writes is the record. See
references/record.md for the record's shape and the phase states.
"""
from __future__ import annotations

import argparse
import functools
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterator


class Refused(Exception):
    """A command that cannot do its job; the message says why."""


def git(*args: str) -> subprocess.CompletedProcess:
    """Run git in the current directory. Never raises on a non-zero exit."""
    return subprocess.run(["git", *args], capture_output=True, text=True)


def main_checkout() -> Path | None:
    """The main checkout's root, the same from any worktree; None outside a repo."""
    r = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    out = r.stdout.strip()
    if r.returncode != 0 or not out:
        return None
    return Path(out).parent


def dumps(value: object) -> str:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def no_constant(name: str) -> None:
    raise ValueError(f"{name} is not JSON")


def parse_json(text: str, where: str) -> Any:
    """Strict JSON: NaN and Infinity, which json.loads accepts, are refused."""
    try:
        return json.loads(text, parse_constant=no_constant)
    except ValueError as e:
        raise Refused(f"{where} is not valid JSON: {e}")


def read_text(path: str, what: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        raise Refused(f"no {what} at {path}")
    except UnicodeDecodeError:
        raise Refused(f"the {what} {path} is not UTF-8 text")
    except OSError as e:
        raise Refused(f"cannot read the {what} {path}: {e.strerror}")


def load_record(path: str) -> dict:
    record = parse_json(read_text(path, "record"), path)
    if not isinstance(record, dict) or not isinstance(record.get("phases"), list):
        raise Refused(f"{path} is not a record: it has no phases array")
    return record


def phase_of(record: dict, pid: str) -> dict:
    for ph in record["phases"]:
        if isinstance(ph, dict) and ph.get("id") == pid:
            return ph
    raise Refused(f"no phase '{pid}' in the record")


@functools.lru_cache(maxsize=None)
def worktree_roots() -> tuple:
    """Every working tree of the repo, the main checkout first (one git call per run)."""
    r = git("worktree", "list", "--porcelain")
    return tuple(Path(line[len("worktree "):]) for line in r.stdout.splitlines()
                 if line.startswith("worktree "))


@functools.lru_cache(maxsize=None)
def ref_exists(ref: str) -> bool:
    return git("rev-parse", "-q", "--verify", ref).returncode == 0


@functools.lru_cache(maxsize=None)
def has_file(ref: str, path: str) -> bool:
    """PATH is in REF's tree."""
    return git("cat-file", "-e", f"{ref}:{path}").returncode == 0


def build_file(pid: str) -> str:
    """The build results file a phase's branch commits before finishing."""
    return f"docs/superpowers/plans/{pid}.build.json"


def phase_branches(pid: str) -> list:
    """The phase's branches that exist: `worktree-<id>` from EnterWorktree, `<id>` in place."""
    return [b for b in (f"worktree-{pid}", pid) if ref_exists(f"refs/heads/{b}")]


def has_workspace(plan: str) -> bool:
    """Some working tree holds an SDD workspace for PLAN: a build is under way."""
    for root in worktree_roots():
        for f in sorted((root / ".superpowers" / "sdd").glob("*/plan-path")):
            if f.is_file() and plan in f.read_text(encoding="utf-8").splitlines():
                return True
    return False


def phase_state(record: dict, pid: str) -> str:
    """One state from record.md's Phase states table, by the first rule that fits."""
    ph = phase_of(record, pid)
    if ph.get("status") == "dropped":
        return "dropped"
    if main_checkout() is None:
        raise Refused("not in a git repository")
    plan = ph.get("plan")
    if plan and has_workspace(plan):
        return "cut-off"
    closing = ph.get("closing")
    closed = isinstance(closing, dict) and closing.get("replan") is not None
    base = record.get("base", "")
    if not isinstance(base, str) or not base or not ref_exists(f"refs/heads/{base}"):
        # Every rule below reads base; without it a built phase would read
        # not-started, and Build would reset its branch.
        raise Refused(f"no branch '{base}' (the record's base) in this repository")
    results = build_file(pid)
    if has_file(f"refs/heads/{base}", results):
        return "done" if closed else "close-missed"
    branches = phase_branches(pid)
    if len(branches) > 1:
        return "anomaly"
    if branches:
        b = branches[0]
        if has_file(f"refs/heads/{b}", results):
            return "closed-unmerged" if closed else "finished-unclosed"
        own = git("rev-list", "--count", f"refs/heads/{base}..refs/heads/{b}").stdout.strip()
        if own not in ("", "0"):
            return "anomaly"
    return "not-started"


def phase_ids(record: dict) -> list:
    return [ph.get("id") for ph in record["phases"] if isinstance(ph, dict)]


ITEM_PREFIX = "Partner item: "
DISPOSITION = re.compile(r"\[(settled: \S+|dropped|carried|adopted by \S+)\]\s*$")


def disposition(line: str) -> str | None:
    """The word of the line's disposition suffix; None for an open item."""
    m = DISPOSITION.search(line)
    return m.group(1).split()[0] if m else None


def unfinished_lines(ph: Any) -> list:
    """The partner-item lines of a phase's closing.unfinished, with their indexes."""
    closing = ph.get("closing") if isinstance(ph, dict) else None
    unfinished = closing.get("unfinished") if isinstance(closing, dict) else None
    if not isinstance(unfinished, list):
        return []
    return [(i, x) for i, x in enumerate(unfinished)
            if isinstance(x, str) and x.startswith(ITEM_PREFIX)]


def open_items(record: dict) -> list:
    """Every partner item with no disposition, in every phase, in array order."""
    return [{"phase": ph.get("id"), "item": x}
            for ph in record["phases"]
            for _, x in unfinished_lines(ph) if disposition(x) is None]


def efforts_dir_of(override: str | None = None) -> Path:
    """OVERRIDE (an --efforts-dir value) when given, else the main checkout's efforts directory."""
    if override:
        return Path(override)
    main = main_checkout()
    if main is None:
        raise Refused("not in a git repository")
    return main / "docs" / "superpowers" / "efforts"


def readable_records(args: argparse.Namespace, subcommand: str) -> Iterator[tuple[Path, dict]]:
    """Each readable record in the efforts directory, by path; a note on stderr for the rest."""
    for rec in sorted(efforts_dir_of(args.efforts_dir).glob("*.json")):
        if not rec.is_file():
            continue
        try:
            yield rec, load_record(str(rec))
        except Refused as e:
            print(f"record {subcommand}: skipping {rec}: {e}", file=sys.stderr)


def cmd_open_efforts(args: argparse.Namespace) -> int:
    for rec, record in readable_records(args, "open-efforts"):
        try:
            if (any(phase_state(record, p) not in ("done", "dropped") for p in phase_ids(record))
                    or open_items(record)):
                print(rec)
        except Refused as e:
            print(f"record open-efforts: skipping {rec}: {e}", file=sys.stderr)
    return 0


def cmd_phase_state(args: argparse.Namespace) -> int:
    print(phase_state(load_record(args.rec), args.id))
    return 0


def cmd_pick(args: argparse.Namespace) -> int:
    record = load_record(args.rec)
    ids = phase_ids(record)
    states = {p: phase_state(record, p) for p in ids}
    first_open = None
    for p in ids:
        s = states[p]
        if s in ("done", "dropped"):
            continue
        if first_open is None:
            first_open = p
        if s != "not-started":
            continue
        deps = phase_of(record, p).get("depends_on") or []
        if all(states.get(d) == "done" for d in deps):
            print(f"id:{p}")
            return 0
    if first_open is not None:
        print(f"blocked:{first_open}")
    else:
        print("items" if open_items(record) else "none")
    return 0


def cmd_carried(args: argparse.Namespace) -> int:
    out = []
    for rec, record in readable_records(args, "carried"):
        out.extend({"record": str(rec), "phase": ph.get("id"), "index": i, "item": x}
                   for ph in record["phases"]
                   for i, x in unfinished_lines(ph) if disposition(x) == "carried")
    print(dumps(out))
    return 0


def cmd_get(args: argparse.Namespace) -> int:
    ph = phase_of(load_record(args.rec), args.id)
    if args.field is None:
        print(dumps(ph))
        return 0
    if args.field.startswith("closing."):
        key = args.field[len("closing."):]
        if key not in CLOSING_KEYS:
            raise Refused(f"'{key}' is not a closing key ({', '.join(CLOSING_KEYS)})")
        closing = ph.get("closing")
        if closing is not None and not isinstance(closing, dict):
            raise Refused(f"phase '{args.id}' has a closing that is not an object")
        print(dumps(None if closing is None else closing.get(key)))
        return 0
    if args.field not in ph:
        raise Refused(f"phase '{args.id}' has no field '{args.field}'")
    print(dumps(ph[args.field]))
    return 0


def cmd_questions(args: argparse.Namespace) -> int:
    record = load_record(args.rec)
    phase_of(record, args.id)
    out = []
    for ph in record["phases"]:
        qs = [w.get("question") for w in (ph.get("waits_on") or [])
              if isinstance(w, dict) and w.get("from") == args.id]
        if qs:
            out.append({"phase": ph.get("id"), "q": qs})
    print(dumps(out))
    return 0


PHASE_KEYS = sorted(["closing", "depends_on", "id", "partner_questions",
                     "plan", "spec", "status", "title", "waits_on"])
CLOSING_KEYS = ("rulings", "unfinished", "learned", "replan")
EFFORT_KEYS = ("learned",)


def read_value(args: argparse.Namespace) -> Any:
    """The JSON value of --value or --value-file (argparse requires exactly one)."""
    if args.value is not None:
        return parse_json(args.value, "--value")
    return parse_json(read_text(args.value_file, "value file"), args.value_file)


def write_record(path: str, record: dict) -> None:
    """Write the record through <path>.tmp and an atomic rename."""
    try:
        data = (json.dumps(record, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    except UnicodeEncodeError:
        raise Refused("the value holds text that cannot be written as UTF-8; nothing written")
    tmp = path + ".tmp"
    try:
        Path(tmp).write_bytes(data)
        os.replace(tmp, path)
    except OSError as e:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise Refused(f"cannot write {path}: {e.strerror}; nothing written")


def string_list(value: Any) -> bool:
    """A list whose items are all strings."""
    return isinstance(value, list) and all(isinstance(x, str) for x in value)


def whole_phases(value: Any) -> bool:
    """An array of whole phases: exactly the nine keys each, and no id repeated."""
    if not isinstance(value, list):
        return False
    if not all(isinstance(ph, dict) and sorted(ph) == PHASE_KEYS for ph in value):
        return False
    ids = [dumps(ph["id"]) for ph in value]
    return len(set(ids)) == len(ids)


def cmd_new_record(args: argparse.Namespace) -> int:
    if Path(args.rec).exists():
        raise Refused(f"{args.rec} already exists")
    value = read_value(args)
    if not (isinstance(value, dict) and isinstance(value.get("umbrella"), str)
            and isinstance(value.get("base"), str) and whole_phases(value.get("phases"))):
        raise Refused("the value is not a whole record of the shape in record.md")
    if "learned" in value and value["learned"] is not None and not string_list(value["learned"]):
        raise Refused("the value's learned is neither null nor a list of strings")
    try:
        Path(args.rec).parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise Refused(f"cannot create {Path(args.rec).parent}: {e.strerror}")
    write_record(args.rec, value)
    return 0


def cmd_set(args: argparse.Namespace) -> int:
    record = load_record(args.rec)
    ph = phase_of(record, args.id)
    if args.field not in ph:
        raise Refused(f"phase '{args.id}' has no field '{args.field}'")
    ph[args.field] = read_value(args)
    write_record(args.rec, record)
    return 0


def cmd_set_phases(args: argparse.Namespace) -> int:
    record = load_record(args.rec)
    value = read_value(args)
    if not whole_phases(value):
        raise Refused("the value is not an array of whole phases with distinct ids")
    record["phases"] = value
    write_record(args.rec, record)
    return 0


def edit_lines(current: list, value: Any, key: str) -> list:
    """The list after an edit: each [old, new] pair, then each drop.

    Each listed line takes the first element equal to it that no earlier
    listed line took. A line that is not there refuses the whole edit.
    """
    if not isinstance(value, dict) or not value or set(value) - {"drop", "edit"}:
        raise Refused(f"the value for an edit of {key} must be an object with drop, edit or both")
    pairs, drops = value.get("edit", []), value.get("drop", [])
    if not isinstance(pairs, list) or not all(
            isinstance(p, list) and len(p) == 2 and all(isinstance(x, str) for x in p) for p in pairs):
        raise Refused("edit must be a list of [old, new] pairs of strings")
    if not isinstance(drops, list) or not all(isinstance(x, str) for x in drops):
        raise Refused("drop must be a list of strings")
    if not pairs and not drops:
        raise Refused(f"the edit of {key} names no line")
    out = list(current)
    taken = [False] * len(out)
    dropped = [False] * len(out)

    def find(line: str) -> int:
        for i, x in enumerate(out):
            if not taken[i] and x == line:
                taken[i] = True
                return i
        shown = line if len(line) <= 60 else line[:60] + "…"
        raise Refused(f"'{shown}' is not a line of {key}")

    for old, new in pairs:
        out[find(old)] = new
    for line in drops:
        dropped[find(line)] = True
    return [x for i, x in enumerate(out) if not dropped[i]]


def apply_mode(current: list, value: Any, mode: str, key: str) -> list:
    """The list after MODE: VALUE (replace), CURRENT then VALUE (append), or CURRENT edited.

    The caller has checked that CURRENT is a list, and VALUE too for append and replace.
    """
    if mode == "replace":
        return value
    if mode == "append":
        return current + value
    return edit_lines(current, value, key)


def cmd_set_closing_key(args: argparse.Namespace) -> int:
    if args.key not in CLOSING_KEYS:
        raise Refused(f"'{args.key}' is not a closing key ({', '.join(CLOSING_KEYS)})")
    if args.key == "replan" and args.mode != "replace":
        raise Refused("replan is written whole, with replace")
    record = load_record(args.rec)
    ph = phase_of(record, args.id)
    value = read_value(args)
    if args.mode != "edit" and not isinstance(value, list):
        raise Refused(f"the value for {args.key} must be a JSON list")
    closing = ph.get("closing")
    if closing is None:
        closing = {"rulings": [], "unfinished": [], "learned": None, "replan": None}
    elif not isinstance(closing, dict):
        raise Refused(f"phase '{args.id}' has a closing that is not an object")
    current = []
    if args.mode in ("append", "edit"):
        current = closing.get(args.key) or []
        if not isinstance(current, list):
            raise Refused(f"phase '{args.id}' has a {args.key} that is not a list")
    closing[args.key] = apply_mode(current, value, args.mode, args.key)
    ph["closing"] = closing
    write_record(args.rec, record)
    return 0


def cmd_get_effort(args: argparse.Namespace) -> int:
    if args.key not in EFFORT_KEYS:
        raise Refused(f"'{args.key}' is not an effort key ({', '.join(EFFORT_KEYS)})")
    print(dumps(load_record(args.rec).get(args.key)))
    return 0


def cmd_set_effort_key(args: argparse.Namespace) -> int:
    if args.key not in EFFORT_KEYS:
        raise Refused(f"'{args.key}' is not an effort key ({', '.join(EFFORT_KEYS)})")
    record = load_record(args.rec)
    value = read_value(args)
    if args.mode != "edit" and not string_list(value):
        raise Refused(f"the value for {args.key} must be a JSON list of strings")
    current = []
    if args.mode != "replace":
        current = record.get(args.key) or []
        if not isinstance(current, list):
            raise Refused(f"the record's {args.key} is not a list")
    result = apply_mode(current, value, args.mode, args.key)
    if not string_list(result):
        raise Refused(f"the record's {args.key} would hold a line that is not a string")
    record[args.key] = result
    write_record(args.rec, record)
    return 0


def add_value(p: argparse.ArgumentParser) -> None:
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--value", metavar="JSON", help="the JSON value, written literally")
    g.add_argument("--value-file", metavar="PATH", help="a file holding the JSON value")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="record.py", description="The commands of an effort record.")
    sub = parser.add_subparsers(dest="cmd", required=True, metavar="SUBCOMMAND")

    p = sub.add_parser("open-efforts", help="list records with a phase not done or dropped, or an open partner item")
    p.add_argument("--efforts-dir")
    p.set_defaults(func=cmd_open_efforts)

    p = sub.add_parser("phase-state", help="print one phase's state")
    p.add_argument("rec")
    p.add_argument("id")
    p.set_defaults(func=cmd_phase_state)

    p = sub.add_parser("pick", help="print id:<id>, blocked:<id>, items or none")
    p.add_argument("rec")
    p.set_defaults(func=cmd_pick)

    p = sub.add_parser("get", help="print a phase, one of its fields, or one closing key (closing.KEY), as JSON")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("field", nargs="?")
    p.set_defaults(func=cmd_get)

    p = sub.add_parser("questions", help="print the waits_on questions phase ID must answer")
    p.add_argument("rec")
    p.add_argument("id")
    p.set_defaults(func=cmd_questions)

    p = sub.add_parser("carried", help="print the [carried] partner items of every record")
    p.add_argument("--efforts-dir")
    p.set_defaults(func=cmd_carried)

    p = sub.add_parser("new-record", help="create the record")
    p.add_argument("rec")
    add_value(p)
    p.set_defaults(func=cmd_new_record)

    p = sub.add_parser("set", help="set one field of a phase")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("field")
    add_value(p)
    p.set_defaults(func=cmd_set)

    p = sub.add_parser("set-phases", help="replace the phases array")
    p.add_argument("rec")
    add_value(p)
    p.set_defaults(func=cmd_set_phases)

    p = sub.add_parser("set-closing-key", help="set or extend one key of a phase's closing")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("key")
    p.add_argument("mode", choices=["replace", "append", "edit"])
    add_value(p)
    p.set_defaults(func=cmd_set_closing_key)

    p = sub.add_parser("get-effort", help="print one effort-level key (learned) as JSON")
    p.add_argument("rec")
    p.add_argument("key")
    p.set_defaults(func=cmd_get_effort)

    p = sub.add_parser("set-effort-key", help="set or extend one effort-level key (learned)")
    p.add_argument("rec")
    p.add_argument("key")
    p.add_argument("mode", choices=["replace", "append", "edit"])
    add_value(p)
    p.set_defaults(func=cmd_set_effort_key)
    return parser


def main(argv: list) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except Refused as e:
        print(f"record {args.cmd}: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
