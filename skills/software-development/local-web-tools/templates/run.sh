#!/usr/bin/env bash
# Idempotent launcher for a local static web tool.
# Copy into the project root, rename UNIT/PORT, chmod +x.
# Set <TOOL>_NO_OPEN=1 to start the server without opening a browser (used by tests).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8765
UNIT="my-local-tool.service"          # NB: --unit= wants the name WITHOUT .service
URL="http://127.0.0.1:${PORT}/"

# 1. Already serving? Nothing to do (menu item clicked twice is the normal case).
if ! curl --fail --silent --max-time 1 "$URL" >/dev/null 2>&1; then
  if systemctl --user is-active --quiet "$UNIT"; then
    systemctl --user restart "$UNIT"   # running but not answering -> kick it
  else
    PYTHON="$(command -v python3 || command -v python)"
    # --collect: tear the transient unit down when the server exits
    # --property=WorkingDirectory: serve the project dir, not $HOME
    systemd-run --user --unit="${UNIT%.service}" --collect \
      --property="WorkingDirectory=$ROOT" \
      "$PYTHON" -m http.server "$PORT" --bind 127.0.0.1 >/dev/null
  fi

  # 2. Poll until the port answers; never sleep blindly for a fixed time.
  for _ in {1..40}; do
    curl --fail --silent --max-time 1 "$URL" >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

# 3. Fail loudly if the server never came up.
curl --fail --silent --max-time 2 "$URL" >/dev/null

if [[ "${MY_TOOL_NO_OPEN:-0}" != "1" ]]; then
  xdg-open "$URL" >/dev/null 2>&1 &
fi
printf '已启动：%s\n' "$URL"
