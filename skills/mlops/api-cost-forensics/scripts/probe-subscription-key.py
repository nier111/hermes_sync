#!/usr/bin/env python3
"""Probe a CN subscription (Token Plan / Coding Plan) key: is it REAL, and how much window is left.

Why this exists: a key that "looks right" in a config file can be
  (a) a redaction artifact pasted from chat/tool output (e.g. literally 13 bytes
      `sk-cp-...atGk`, same head AND tail as the real key), or
  (b) the right length but revoked/expired (401 on every endpoint).
Guessing costs a whole debugging round; this script settles it in one call.

Usage
  # key inside an .env-style file
  python3 probe-subscription-key.py --file ~/.hermes/profiles/gf/.env --var MINIMAX_API_KEY

  # key inside OpenClaw's sqlite auth store
  python3 probe-subscription-key.py --file ~/.openclaw/state/openclaw.sqlite --sqlite-key minimax:default

  # literal key (quote it)
  python3 probe-subscription-key.py --key 'sk-cp-...'

Exit code 0 = key authenticated (HTTP 200 with expected text). Non-zero = not usable.

Only stdlib. No third-party deps.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import urllib.error
import urllib.request

BASE = "https://api.minimax.io"          # global; CN console keys work here too
PROBE_MODEL = "MiniMax-M3"
PROBE_TEXT = "MINIMAX_OK"


def mask(k: str) -> str:
    if len(k) <= 12:
        return k
    return f"{k[:5]}...{k[-4:]}"


def key_from_env_file(path: str, var: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith(f"{var}="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"{var} not found in {path}")


def key_from_sqlite(path: str, profile: str) -> str:
    """OpenClaw stores provider creds in config_machine_state['authProfiles.store']."""
    db = sqlite3.connect(path)
    row = db.execute(
        "SELECT value_json FROM config_machine_state WHERE state_key='authProfiles.store'"
    ).fetchone()
    db.close()
    if not row:
        raise SystemExit("authProfiles.store row not found")
    profiles = json.loads(row[0]).get("profiles", {})
    if profile not in profiles:
        raise SystemExit(f"profile {profile!r} not in auth store; have {sorted(profiles)}")
    return profiles[profile].get("key", "")


def post_message(key: str) -> tuple[bool, str]:
    data = json.dumps(
        {
            "model": PROBE_MODEL,
            "max_tokens": 32,                      # thinking models need headroom; 16 works on M3
            "messages": [{"role": "user", "content": f"Reply with exactly: {PROBE_TEXT}"}],
        }
    ).encode()
    req = urllib.request.Request(
        f"{BASE}/anthropic/v1/messages",
        data=data,
        headers={
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = json.loads(r.read())
        text = "".join(b.get("text", "") for b in body.get("content", []))
        return True, f"HTTP 200 model={body.get('model')} text={text!r} usage={body.get('usage')}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code} {e.read().decode()[:200]}"
    except Exception as e:  # noqa: BLE001 - report any transport failure verbatim
        return False, f"{type(e).__name__}: {e}"


def token_plan_windows(key: str) -> str:
    req = urllib.request.Request(
        f"{BASE}/v1/token_plan/remains", headers={"Authorization": f"Bearer {key}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            body = json.loads(r.read())
    except urllib.error.HTTPError as e:
        return f"HTTP {e.code} {e.read().decode()[:160]}"
    m = (body.get("model_remains") or [{}])[0]
    # Counters read 0/0 even on working keys -> trust the PERCENT fields only.
    return (
        f"5h window  {m.get('current_interval_remaining_percent')}% left "
        f"({m.get('start_time')} -> {m.get('end_time')})\n"
        f"week window {m.get('current_weekly_remaining_percent')}% left "
        f"({m.get('weekly_start_time')} -> {m.get('weekly_end_time')})"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--file", help="file to read the key from (.env or sqlite)")
    src.add_argument("--key", help="literal key")
    ap.add_argument("--var", default="MINIMAX_API_KEY", help="env var name when --file is a .env")
    ap.add_argument("--sqlite-key", help="profile id, e.g. minimax:default (--file = sqlite path)")
    ap.add_argument("--skip-windows", action="store_true")
    args = ap.parse_args()

    if args.key:
        key = args.key
    elif args.sqlite_key:
        key = key_from_sqlite(args.file, args.sqlite_key)
    else:
        key = key_from_env_file(args.file, args.var)

    print(f"key length : {len(key)} bytes")          # real check; 13 => pasted redaction artifact
    print(f"key        : {mask(key)}")
    if len(key) < 40:
        print("!! implausibly short: this is almost certainly a masked/redacted placeholder,")
        print("   not the key itself. Re-copy the WHOLE value.")

    ok, detail = post_message(key)
    print(f"round-trip : {'OK' if ok else 'FAIL'} - {detail}")
    if ok and not args.skip_windows:
        print("quota     :\n" + token_plan_windows(key))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
