#!/usr/bin/env python3
"""Aggregate OpenClaw per-call token usage out of the agent SQLite.

Answers "what actually burned the quota?" with recorded numbers instead of
guesses. Read-only (URI mode=ro); prints no secrets.

Usage:
  python3 openclaw-session-usage.py                    # per-session+model totals
  python3 openclaw-session-usage.py --model kimi       # only models matching
  python3 openclaw-session-usage.py --session 8203a11f # one session
  python3 openclaw-session-usage.py --timeline         # per-call table (loop hunt)

Loop-hunt reading of --timeline: calls at a metronome interval with IDENTICAL
`out` and `in` creeping by a few tokens are a runaway retry/echo loop, not work.
"""
import argparse
import collections
import datetime
import glob
import json
import os
import sqlite3
import sys


def fmt_ts(ms):
    if not ms:
        return "??"
    return datetime.datetime.fromtimestamp(ms / 1000).strftime("%m-%d %H:%M:%S")


def find_dbs():
    return sorted(glob.glob(os.path.expanduser("~/.openclaw/agents/*/agent/openclaw-agent.sqlite")))


def iter_usage(db):
    """Yield (session_id, seq, created_at_ms, model, usage_dict)."""
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        rows = conn.execute(
            "select session_id, seq, event_json, created_at from transcript_events order by created_at"
        )
        for sid, seq, ej, ca in rows:
            try:
                event = json.loads(ej)
            except Exception:
                continue
            stack = [event]
            while stack:                       # iterative walk, avoids recursion limits
                node = stack.pop()
                if isinstance(node, dict):
                    usage = node.get("usage")
                    if isinstance(usage, dict):
                        model = (node.get("model") or node.get("modelId")
                                 or usage.get("model") or "?")
                        yield sid, seq, (ca if isinstance(ca, int) else 0), str(model), usage
                    stack.extend(node.values())
                elif isinstance(node, list):
                    stack.extend(node)
    finally:
        conn.close()


def num(u, key):
    v = u.get(key, 0)
    return v if isinstance(v, (int, float)) else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", help="substring match on model id")
    ap.add_argument("--session", help="substring match on session id")
    ap.add_argument("--timeline", action="store_true", help="print each call in order")
    ap.add_argument("--db", help="explicit agent sqlite path")
    args = ap.parse_args()

    dbs = [args.db] if args.db else find_dbs()
    if not dbs:
        sys.exit("no agent sqlite found under ~/.openclaw/agents/*/agent/")

    recs = []
    for db in dbs:
        for sid, seq, ms, model, usage in iter_usage(db):
            if args.model and args.model.lower() not in model.lower():
                continue
            if args.session and args.session not in sid:
                continue
            recs.append(dict(sid=sid, seq=seq, ms=ms, model=model, u=usage))

    if not recs:
        sys.exit("no matching usage records")

    by = collections.defaultdict(list)
    for r in recs:
        by[(r["sid"], r["model"])].append(r)

    print(f"{'session':10} {'model':26} {'calls':>5} {'in+cacheR':>12} {'out':>8} "
          f"{'first':>15} {'last':>15}")
    print("-" * 100)
    for (sid, model), rs in sorted(by.items(), key=lambda kv: -sum(num(x["u"], "input") + num(x["u"], "cacheRead") for x in kv[1])):
        total_in = sum(num(x["u"], "input") + num(x["u"], "cacheRead") for x in rs)
        total_out = sum(num(x["u"], "output") for x in rs)
        print(f"{sid[:8]:10} {model[:26]:26} {len(rs):>5} {total_in:>12,} {total_out:>8,} "
              f"{fmt_ts(rs[0]['ms']):>15} {fmt_ts(rs[-1]['ms']):>15}")

    if args.timeline:
        print("\n=== per-call timeline (loop hunt) ===")
        print(f"{'time':15} {'model':22} {'in':>7} {'cacheR':>8} {'out':>6}  running")
        for r in recs:
            u = r["u"]
            print(f"{fmt_ts(r['ms']):15} {r['model'][:22]:22} {num(u,'input'):>7,} "
                  f"{num(u,'cacheRead'):>8,} {num(u,'output'):>6,}")
        print("\nHINT: identical `out` on consecutive calls at a steady interval, with `in`"
              "\n      creeping up a few tokens, is a runaway loop — pure waste, interrupt it.")


if __name__ == "__main__":
    main()
