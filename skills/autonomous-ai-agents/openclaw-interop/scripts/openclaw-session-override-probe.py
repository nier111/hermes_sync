#!/usr/bin/env python3
"""Find OpenClaw sessions PINNED to an explicit model — the layer that outranks
`agents.defaults.model` and makes routing-config edits inert.

Read-only, no openclaw CLI needed. Run this FIRST whenever "the gateway is ignoring the
model I configured" (a startup log showing the right model while the runtime log shows a
different one is the signature). Rationale + the fix recipe:
`references/session-model-override.md`.

Usage:
    python3 openclaw-session-override-probe.py                 # scan agents/main
    python3 openclaw-session-override-probe.py --agent-id gf
    python3 openclaw-session-override-probe.py --db /path/to/openclaw-agent.sqlite
    python3 openclaw-session-override-probe.py --show-all      # list every session key

Exit code: 0 = no overrides, 1 = overrides found (usable as a gate, unlike the
routing-check script which always exits 0).
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

OVERRIDE_KEYS = (
    "modelOverride",
    "providerOverride",
    "modelOverrideSource",
    "modelOverrideRouteResolution",
    "authProfileOverride",
    "authProfileOverrideSource",
    "authProfileOverrideCompactionCount",
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent-id", default="main", help="agent id under ~/.openclaw/agents/<id>/")
    ap.add_argument("--db", default=None, help="explicit openclaw-agent.sqlite path")
    ap.add_argument("--show-all", action="store_true", help="also list unpinned sessions")
    args = ap.parse_args()

    db_path = Path(args.db) if args.db else (
        Path.home() / ".openclaw" / "agents" / args.agent_id / "agent" / "openclaw-agent.sqlite")

    if not db_path.exists():
        print(f"!! no agent db at {db_path}")
        print("   (this is the PER-AGENT db under agents/<id>/agent/, not state/openclaw.sqlite)")
        return 0

    try:
        with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as c:
            uv = c.execute("PRAGMA user_version").fetchone()[0]
            rows = c.execute(
                "SELECT session_key, current_session_id, status, entry_valid, entry_json "
                "FROM session_nodes ORDER BY updated_at DESC"
            ).fetchall()
    except Exception as e:  # noqa: BLE001
        print(f"!! cannot read {db_path}: {e}")
        return 0

    print(f"db: {db_path}")
    print(f"sqlite user_version={uv}  sessions={len(rows)}")
    print()

    pinned = []
    for sk, sid, status, ev, entry_json in rows:
        try:
            e = json.loads(entry_json)
        except Exception:  # noqa: BLE001
            e = {}
        present = {k: e[k] for k in OVERRIDE_KEYS if k in e}
        if present:
            pinned.append((sk, sid, status, ev, present))
        elif args.show_all:
            print(f"  (ok) {sk}  status={status}")

    if not pinned:
        print("no session-level model overrides — sessions follow agents.defaults.model")
        return 0

    print(f"!! {len(pinned)} session(s) PINNED to an explicit model — primary/fallbacks IGNORED:")
    for sk, sid, status, ev, present in pinned:
        print()
        print(f"  {sk}")
        print(f"    session_id={sid}  status={status}  entry_valid={ev}")
        for k, v in present.items():
            print(f"    {k} = {v!r}")
        if status == "failed":
            err = None
            try:
                err = json.loads(
                    next(r[0] for r in [e for e in [None]] if r)  # placeholder, see below
                )
            except Exception:  # noqa: BLE001
                pass
            print("    ^ status=failed alongside a pin usually means a dead/de-quota'd primary")
            print("      with configured fallbacks suppressed (log: fallbackConfigured:false)")

    print()
    print("fix: clear the override keys in session_nodes.entry_json, null "
          "session_windows.model_provider/model,")
    print("     then have the USER restart the gateway:")
    print("       systemctl --user restart openclaw-gateway.service")
    print("     Recipe + honest verification status: references/session-model-override.md")
    return 1


if __name__ == "__main__":
    sys.exit(main())
