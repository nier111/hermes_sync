#!/usr/bin/env bash
# Probe local OpenClaw gateway state. Prints a summary; always exits 0.
# Run before relying on the OpenClaw HTTP API.
set -u
GW=127.0.0.1:18789

echo "== gateway process =="
ps -eo pid,lstart,etime,cmd | grep -E "dist/index.js gateway" | grep -v grep || echo "no gateway process"

echo "== port 18789 =="
ss -tln | grep 18789 || echo "port 18789 not listening"

echo "== update in progress? =="
ps -eo pid,etime,cmd | grep -E "openclaw (update|updater)" | grep -v grep || echo "no update running"

echo "== dist vs process age (mismatch => mid-update mixed state) =="
stat -c 'dist/index.js modified: %y' "$HOME/projects/openclaw/dist/index.js" 2>/dev/null || echo "dist/index.js missing"

echo "== endpoint codes (200/4xx OK; 404 on all => stale gateway mid-update) =="
for p in /docs /api/me /api/v1/rpc; do
  printf "%-14s " "$p"
  curl -s -m 4 -o /dev/null -w "%{http_code}\n" "http://$GW$p"
done
