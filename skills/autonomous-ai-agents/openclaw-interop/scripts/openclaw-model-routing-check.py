#!/usr/bin/env python3
"""Report OpenClaw model routing + auth-profile state, and probe the local gateway.

Read-only. Does NOT need the openclaw CLI (useful when CLI/gateway schema drift makes
the CLI unusable). Run AFTER the user has restarted the gateway.

Usage:
    python3 openclaw-model-routing-check.py [--json PATH] [--db PATH] [--port 18789]

Exit code is always 0 — read the output, don't gate on it.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

DEFAULT_JSON = Path.home() / ".openclaw" / "openclaw.json"
DEFAULT_DB = Path.home() / ".openclaw" / "state" / "openclaw.sqlite"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=str(DEFAULT_JSON))
    ap.add_argument("--db", default=str(DEFAULT_DB))
    ap.add_argument("--port", type=int, default=18789)
    ap.add_argument("--agent", default="defaults", help="agent id under agents.<id>, or 'defaults'")
    args = ap.parse_args()

    cfg_path = Path(args.json)
    print("=== 1. routing config ===")
    try:
        d = json.loads(cfg_path.read_text())
    except Exception as e:  # noqa: BLE001
        print(f"  !! cannot parse {cfg_path}: {e}")
        return 0

    ag = d.get("agents", {}).get(args.agent, {})
    model = ag.get("model", {})
    print(f"  file:      {cfg_path}")
    print(f"  agent:     {args.agent}")
    print(f"  primary:   {model.get('primary')}")
    print(f"  fallbacks: {model.get('fallbacks')}")
    allow = ag.get("modelPolicy", {}).get("allow", [])
    print(f"  allowlist ({len(allow)}): {allow}")
    print(f"  declared model aliases: {list(ag.get('models', {}).keys())}")

    enabled = {k: v.get("enabled") for k, v in d.get("plugins", {}).get("entries", {}).items()
               if v.get("enabled")}
    print(f"  enabled plugins: {sorted(enabled)}")
    providers = list(d.get("models", {}).get("providers", {}).keys())
    print(f"  models.providers stanzas: {providers}")
    if providers:
        print("   ^ if one of these shares an id with a bundled provider plugin, it OVERRIDES")
        print("     the plugin default — remove it unless you really want the override.")

    # consistency check: every referenced ref should be in the allowlist
    refs = [r for r in [model.get("primary")] + list(model.get("fallbacks") or []) if r]
    missing = [r for r in refs if r not in allow]
    if missing:
        print(f"  WARN: refs not in modelPolicy.allow: {missing}")

    print()
    print("=== 2. auth profiles (sqlite) ===")
    db_path = Path(args.db)
    try:
        with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as c:
            row = c.execute(
                "SELECT value_json FROM config_machine_state WHERE state_key='authProfiles.store'"
            ).fetchone()
            uv = c.execute("PRAGMA user_version").fetchone()[0]
    except Exception as e:  # noqa: BLE001
        print(f"  !! cannot read {db_path}: {e}")
        return 0

    print(f"  db: {db_path}  (sqlite user_version={uv})")
    if not row:
        print("  !! no authProfiles.store row")
    else:
        profiles = json.loads(row[0]).get("profiles", {})
        for pid, p in sorted(profiles.items()):
            secret = p.get("key") or p.get("access") or ""
            print(f"  {pid:22s} type={p.get('type'):8s} provider={p.get('provider'):12s} "
                  f"secret={secret[:6]}…(len={len(secret)})")
        # which of the routed providers have a credential?
        want = {r.split("/", 1)[0] for r in refs}
        have = {p.get("provider") for p in profiles.values()}
        lacking = sorted(want - have)
        if lacking:
            print(f"  WARN: routed providers with no auth profile: {lacking}")

    print()
    print("=== 3. gateway probes ===")
    for ep in ("/api/me", "/api/v1/models", "/api/channels"):
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{args.port}{ep}")
            with urllib.request.urlopen(req, timeout=3) as r:
                print(f"  GET {ep} -> HTTP {r.status}")
        except Exception as e:  # noqa: BLE001
            print(f"  GET {ep} -> {type(e).__name__}: {e}")

    print()
    print("=== 4. end-to-end (do this by hand) ===")
    print("  Send a real message through the channel (QQ etc.) and confirm which")
    print("  provider/model answered in the gateway log — config edits alone are not proof.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
