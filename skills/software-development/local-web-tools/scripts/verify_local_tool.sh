#!/usr/bin/env bash
# Re-runnable end-to-end check for a local static web tool built with this skill.
#
#   scripts/verify_local_tool.sh <project-dir> [port] [marker-string] [data-json] [expected-count]
#
# Example:
#   verify_local_tool.sh ~/projects/yao-vocab-sieve 8765 '词筛' data/words.json 6547
#
# Checks, in order: node tests -> asset contract -> launcher up -> HTTP 200s ->
# dataset count -> desktop entry validity. Exits non-zero on the first hard failure.
set -euo pipefail

ROOT="${1:?usage: verify_local_tool.sh <project-dir> [port] [marker] [data-json] [count]}"
PORT="${2:-8765}"
MARKER="${3:-}"
DATA="${4:-}"
EXPECT="${5:-}"
URL="http://127.0.0.1:${PORT}/"
fail=0
note() { printf '%s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; fail=1; }

cd "$ROOT"

# 1. Unit + artifact-contract tests
if [[ -f package.json ]]; then
  if node --test tests/*.test.mjs; then note "tests: PASS"; else bad "node --test"; fi
else
  note "tests: skipped (no package.json)"
fi

# 2. Launcher must be executable and local-only
if [[ -x run.sh ]]; then
  note "launcher: executable"
  grep -q -- '--bind 127.0.0.1' run.sh || bad "run.sh does not bind 127.0.0.1"
  grep -q 'systemd-run'         run.sh || bad "run.sh does not use systemd-run"
  grep -qE '(^|[^a-z])&$|nohup|setsid' run.sh && bad "run.sh uses &/nohup/setsid"
else
  bad "run.sh missing or not executable"
fi

# 3. Bring it up without stealing focus, then wait for readiness
TOOL_NO_OPEN=1 ./run.sh >/dev/null || bad "./run.sh"
for _ in $(seq 1 60); do
  curl --fail --silent --max-time 1 "$URL" >/dev/null 2>&1 && break
  sleep 0.25
done
curl --fail --silent --max-time 2 "$URL" >/dev/null || bad "server not answering $URL"
note "server: $URL reachable"

# 4. Assets actually served, not just 200 on /
for asset in index.html; do
  curl --fail --silent "$URL$asset" >/dev/null || bad "asset $asset not served"
done
if [[ -n "$MARKER" ]]; then
  curl --fail --silent "$URL" | grep -q -- "$MARKER" \
    && note "page marker present: $MARKER" || bad "page marker missing: $MARKER"
fi

# 5. Dataset count, so a silent re-import can't shrink the tool's content
if [[ -n "$DATA" && -n "$EXPECT" ]]; then
  got="$(curl --fail --silent "$URL$DATA" | python3 -c '
import json,sys
d=json.load(sys.stdin)
w=d.get("words") if isinstance(d,dict) else d
print(len(w))')"
  if [[ "$got" == "$EXPECT" ]]; then note "dataset: $got records"; else bad "dataset $got != expected $EXPECT"; fi
fi

# 6. Desktop entry
entry="$(ls "$HOME"/.local/share/applications/*.desktop 2>/dev/null | head -n1 || true)"
if [[ -n "$entry" ]]; then
  if command -v desktop-file-validate >/dev/null; then
    desktop-file-validate "$entry" && note "desktop entry: valid" || bad "desktop-file-validate $entry"
  else
    note "desktop entry: present (desktop-file-validate not installed)"
  fi
  grep -q '^Exec=/' "$entry" || bad "desktop Exec= is not an absolute path"
fi

if [[ "$fail" == 0 ]]; then note "ALL CHECKS PASSED"; else note "CHECKS FAILED"; fi
exit "$fail"
