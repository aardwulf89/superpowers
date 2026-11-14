#!/usr/bin/env python3
"""The commands of a chaining-plans effort record (effort.json).

Run it by its absolute path, one plain command per call:

    python3 <skill base>/scripts/record.py <subcommand> <args>

Subcommands:
    chain-dir
    open-efforts [--chain-dir DIR]
    phase-state REC ID
    pick REC
    get REC ID [FIELD]
    questions REC ID
    new-record REC (--value JSON | --value-file PATH)
    set REC ID FIELD (--value JSON | --value-file PATH)
    set-phases REC (--value JSON | --value-file PATH)
    set-closing-key REC ID KEY {replace,append} (--value JSON | --value-file PATH)

A refused command prints "record <subcommand>: <reason>" on stderr, exits 1,
and changes nothing. A usage error exits 2. Git runs read-only, in the current
directory; the only file this script writes is the record. See
references/record.md for the record's shape and the phase states.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


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


def load_record(path: str) -> dict:
    try:
        text = Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        raise Refused(f"no record at {path}")
    except OSError as e:
        raise Refused(f"cannot read {path}: {e.strerror}")
    try:
        record = json.loads(text)
    except ValueError as e:
        raise Refused(f"{path} is not valid JSON: {e}")
    if not isinstance(record, dict) or not isinstance(record.get("phases"), list):
        raise Refused(f"{path} is not a record: it has no phases array")
    return record


def phase_of(record: dict, pid: str) -> dict:
    for ph in record["phases"]:
        if isinstance(ph, dict) and ph.get("id") == pid:
            return ph
    raise Refused(f"no phase '{pid}' in the record")


def branch_worktree(branch: str) -> Path | None:
    """The worktree that has BRANCH checked out, if any."""
    r = git("worktree", "list", "--porcelain")
    current = None
    for line in r.stdout.splitlines():
        if line.startswith("worktree "):
            current = line[len("worktree "):]
        elif line == f"branch refs/heads/{branch}" and current is not None:
            return Path(current)
    return None


def gh_says_merged(branch: str) -> bool:
    try:
        r = subprocess.run(
            ["gh", "pr", "view", branch, "--json", "state", "-q", ".state"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
    except OSError:
        return False
    return r.stdout.strip() == "MERGED"


def is_merged(branch: str, base: str) -> bool:
    if git("rev-parse", "-q", "--verify", f"refs/heads/{branch}").returncode != 0:
        return True
    if git("merge-base", "--is-ancestor", branch, base).returncode == 0:
        return True
    return gh_says_merged(branch)


def phase_state(record: dict, pid: str) -> str:
    """One state from record.md's Phase states table, by the first rule that fits."""
    ph = phase_of(record, pid)
    if ph.get("status") == "dropped":
        return "dropped"
    branch = ph.get("branch")
    if not branch:
        return "not-started"
    main = main_checkout()
    if main is None:
        raise Refused("not in a git repository")
    plan = ph.get("plan")
    if plan:
        w = branch_worktree(branch) or main
        for f in sorted((w / ".superpowers" / "sdd").glob("*/plan-path")):
            if f.is_file() and plan in f.read_text(encoding="utf-8").splitlines():
                return "cut-off"
    merged = is_merged(branch, record.get("base", ""))
    closing = ph.get("closing")
    closed = isinstance(closing, dict) and closing.get("replan") is not None
    return {
        (True, False): "close-missed",
        (True, True): "done",
        (False, False): "finished-unclosed",
        (False, True): "closed-unmerged",
    }[(merged, closed)]


def phase_ids(record: dict) -> list:
    return [ph.get("id") for ph in record["phases"] if isinstance(ph, dict)]


def cmd_chain_dir(args: argparse.Namespace) -> int:
    main = main_checkout()
    if main is None:
        raise Refused("not in a git repository")
    print(main / ".superpowers" / "chain")
    return 0


def cmd_open_efforts(args: argparse.Namespace) -> int:
    if args.chain_dir:
        chain_dir = Path(args.chain_dir)
    else:
        main = main_checkout()
        if main is None:
            raise Refused("not in a git repository")
        chain_dir = main / ".superpowers" / "chain"
    for rec in sorted(chain_dir.glob("*/effort.json")):
        if not rec.is_file():
            continue
        try:
            record = load_record(str(rec))
            if any(phase_state(record, p) not in ("done", "dropped") for p in phase_ids(record)):
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
    print(f"blocked:{first_open}" if first_open is not None else "none")
    return 0


def cmd_get(args: argparse.Namespace) -> int:
    ph = phase_of(load_record(args.rec), args.id)
    if args.field is None:
        print(dumps(ph))
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


def cmd_not_implemented(args: argparse.Namespace) -> int:
    raise Refused("not implemented")


def add_value(p: argparse.ArgumentParser) -> None:
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--value", metavar="JSON", help="the JSON value, written literally")
    g.add_argument("--value-file", metavar="PATH", help="a file holding the JSON value")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="record.py", description="The commands of an effort record.")
    sub = parser.add_subparsers(dest="cmd", required=True, metavar="SUBCOMMAND")

    sub.add_parser("chain-dir", help="print the main checkout's chain directory").set_defaults(func=cmd_chain_dir)

    p = sub.add_parser("open-efforts", help="list records with a phase not done or dropped")
    p.add_argument("--chain-dir")
    p.set_defaults(func=cmd_open_efforts)

    p = sub.add_parser("phase-state", help="print one phase's state")
    p.add_argument("rec")
    p.add_argument("id")
    p.set_defaults(func=cmd_phase_state)

    p = sub.add_parser("pick", help="print id:<id>, blocked:<id> or none")
    p.add_argument("rec")
    p.set_defaults(func=cmd_pick)

    p = sub.add_parser("get", help="print a phase, or one of its fields, as JSON")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("field", nargs="?")
    p.set_defaults(func=cmd_get)

    p = sub.add_parser("questions", help="print the waits_on questions phase ID must answer")
    p.add_argument("rec")
    p.add_argument("id")
    p.set_defaults(func=cmd_questions)

    p = sub.add_parser("new-record", help="create the record")
    p.add_argument("rec")
    add_value(p)
    p.set_defaults(func=cmd_not_implemented)

    p = sub.add_parser("set", help="set one field of a phase")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("field")
    add_value(p)
    p.set_defaults(func=cmd_not_implemented)

    p = sub.add_parser("set-phases", help="replace the phases array")
    p.add_argument("rec")
    add_value(p)
    p.set_defaults(func=cmd_not_implemented)

    p = sub.add_parser("set-closing-key", help="set or extend one key of a phase's closing")
    p.add_argument("rec")
    p.add_argument("id")
    p.add_argument("key")
    p.add_argument("mode", choices=["replace", "append"])
    add_value(p)
    p.set_defaults(func=cmd_not_implemented)
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
