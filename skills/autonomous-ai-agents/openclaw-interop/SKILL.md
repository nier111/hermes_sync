---
name: openclaw-interop
description: "Inspect/call the local OpenClaw gateway: layout, API, data."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [openclaw, clawdbot, gateway, interop, agents]
---

# OpenClaw Interop

OpenClaw is the community continuation of Clawdbot — a self-hosted personal AI gateway (node process) that bridges messaging platforms (telegram/discord/slack/whatsapp/qqbot...) to an agent. From Hermes you can inspect it, read its data, and call it over its local HTTP API or CLI.

## Discovery

```bash
ps aux | grep -iE "openclaw|clawdbot" | grep -v grep   # gateway + update processes
ss -tlnp | grep 18789                                  # default gateway port
ls ~/.openclaw ~/projects/openclaw                     # data dir + project (pnpm-managed)
```

- Gateway: `node .../dist/index.js gateway --port 18789`, control web UI at `http://127.0.0.1:18789/docs`.
- CLI binary: `~/projects/openclaw/node_modules/.bin/openclaw` (not on PATH); run via `pnpm openclaw ...`.
- Config: `~/.openclaw/openclaw.json` — model providers (moonshot/openrouter/minimax/kimi/deepseek...), channels. No top-level `apiKey` field → localhost API is often auth-less.

## Storage map (where the data actually lives)

- **Chat content**: `~/.openclaw/agents/main/sessions/*.jsonl` — one trajectory file per conversation (JSONL, plain text, can be tens of MB; `.deleted.<ts>` = archived). This is the real conversation store.
- **Semantic memory**: `~/.openclaw/memory/main.sqlite` — vector store (`chunks` + FTS + embeddings, often via local ollama, e.g. nomic-embed-text). Frequently nearly empty; do NOT assume history lives here.
- **Operational state**: `~/.openclaw/state/openclaw.sqlite` — cron jobs, tasks, channel bindings. `channel_ingress_events` is often 0 rows; not the message store.
- **workspace/**: agent files; `workspace/memory/` often holds persona/notes markdown files.
- **qqbot/ (and other channel dirs)**: holds ONLY credentials (e.g. `data/credential-backup.json`), never chat content.

## Finding the HTTP API

The API routes are NOT in server config; grep them from the frontend/control bundle:

```bash
cd ~/projects/openclaw/dist && grep -rhoE '"/api/[a-zA-Z0-9/_:{}.$-]+"' *.js | sort -u
```

Known routes: `/api/chat` (send message), `/api/v1/rpc` (JSON-RPC — what the CLI uses), `/api/me`, `/api/messages`, `/api/prompt`, `/api/channels`, `/api/dms`, `/api/v1/models`.

**As of 2026.7.2 (verified 2026-08-06): the HTTP API changed.** `/api/chat` is gone, most routes 404, and `/api/channels` returns **401 — the new API requires auth** (no plain `apiKey` in config; token flow lives in the frontend bundle). The reliable interaction path is the CLI, which handles auth internally:

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"   # required — see pitfalls
cd ~/projects/openclaw && pnpm openclaw agent --agent main -m "message text" [--json]
```

`agent` subcommand options: `--agent <id>` (list via `pnpm openclaw agents list`), `-m/--message`, `--message-file`, `--json`, `--deliver` (send reply to channel), `--channel <name>` (incl. `qqbot`), `--model`, `--local`. Omitting the agent errors with "No target session selected" — always pass `--agent`.

## Skill inventory & cross-deployment planning

- `pnpm openclaw skills list` prints the full skill table (status / name / description / source; this box: 58 skills, 24 ready, sources `openclaw-bundled` / `openclaw-extra` / `openclaw-workspace`). Install/search via `pnpm openclaw skills search|install|update` (ClawHub).
- OpenClaw's bundled skills heavily overlap Hermes' library (spike, xurl, songsee, summarize, nano-pdf, notion, debugpy, github...). Before installing anything on either side, check the complement plan at `~/persona/skills-complement-plan.md` (regenerated 2026-08-06) — it lists overlaps (don't duplicate), OpenClaw-only gems (circuit-analyzer, healthcheck, qqbot-channel/media/remind, acp-router, clawhub), and Hermes-only skills. Rule of thumb: new capability → check the plan → then ClawHub/Hermes library → only then create fresh.

## Building & version requirements (observed 2026-08-06)

- Version gates live in `package.json`: `engines` (node >=22.22.3 <23) and `packageManager` (pnpm@11.15.1+sha512...). `pnpm build` exits 1 if either is unmet.
- pnpm mismatch: the pacman `/usr/bin/pnpm` (e.g. 11.3.0) does NOT satisfy `packageManager`. Fix: `corepack enable` (writes a shim into the nvm bin dir), then any `pnpm` run INSIDE the project dir auto-downloads/activates the pinned version — verify with `pnpm --version` there.
- node mismatch: `Error: Failed to render source browser help: openclaw: Node.js >=22.22.3 <23 ... is required (current: v22.22.0)` LOOKS like a rendering error but is the engines gate. Fix: `source ~/.nvm/nvm.sh && nvm install 22.22.3 && nvm use 22.22.3`.
- After switching node via nvm, re-run `corepack enable` — the pnpm shim lives under the OLD nvm bin dir and falls off PATH.
- Build is memory-hungry (tsdown; ~3.7GB peak). On a 7.4GB box: run `pnpm build > /tmp/openclaw-build.log 2>&1` in background, then `grep -nE "error|Error|failed" /tmp/openclaw-build.log` — the real error is a single line buried among fastfetch banner noise.
- Retry is cheap: build reuses cached phases (tsdown-unified, ui:build...) after a version fix.

## Pitfalls

- **Hermes terminal env is a per-command snapshot (verified 2026-08-06)**: `nvm use 22.22.3` only sticks within the command that ran it — the next Hermes terminal call gets the old PATH (node 22.22.0) again, and `pnpm openclaw ...` fails the engines gate with "detected Node 22.22.0 (exec: .../v22.22.0/bin/node)" even though `node -v` showed the new version earlier. Fix: prefix EVERY command with `export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"` (also set `nvm alias default 22.22.3` once so interactive shells pick it up). Same applies to background builds.
- **Auto-update hijacks the gateway (observed 2026-08-06)**: the gateway checks for new versions (`~/.openclaw/update-check.json`) and, when one is found, systemd-run's a TRANSIENT user service (`openclaw-updateN.service` — no unit file, appears only via `systemctl --user list-units`) running `pnpm openclaw update --yes`. That flow STOPS the gateway service, git-pulls, and pnpm-installs ALL dependencies (multi-GB; proxied through local clash 7890 if proxy env is set — burns metered/hotspot traffic). Retries show as numbered logs `/tmp/openclaw-updateN.log`. Consequence for interop: a stopped gateway + 404s on the API is often the auto-update in progress, not a crash. After an interrupted update: node_modules half-built, gateway left stopped — recovery is re-running the update (or `pnpm install` + rebuild + `systemctl --user start openclaw-gateway`).
- **Mid-update mixed state**: while `openclaw update --yes` runs, disk `dist/` files are newer than the running process → API returns 404 for routes the frontend knows. Wait for restart before relying on the API.
- Updates run through a local proxy if configured (env `HTTPS_PROXY=http://127.0.0.1:7890` etc. in the update process cmdline) — mirror it when you need outbound network for OpenClaw tooling.
- `~/.openclaw/memory/main.sqlite` being tiny (a handful of chunks) is normal — OpenClaw leans on session files for context.
- Persona/personality files (if any) are plain markdown under `workspace/memory/`, not wired into `openclaw.json`; check there when asked about OpenClaw's "人格"/persona.
- **Gateway can be systemd-managed (verified 2026-08-06)**: `systemctl --user start openclaw-gateway.service` — its ExecStart uses `/usr/bin/node` (v26.5.1, satisfies engines), so it works even when the nvm node is pinned differently. If the user hand-started the gateway in a terminal (process named `openclaw-gateway`), kill that pid first, then start the service; port 18789 flips cleanly and the gateway survives reboots.
- **Memory diet (gateway RSS ~1GB is baseline)**: disable unused channel plugins via `pnpm openclaw plugins disable <id>` (e.g. whatsapp/telegram; keep qqbot) — output says "Restart the gateway to apply". Orphaned chromium trees (ppid=1, `--proxy-server=socks5://127.0.0.1:7891`, no openclaw/hermes env markers) can pile up ~1.5GB after browser-tool use — safe to kill the whole tree (`for p in $(ps -eo pid,ppid,comm | awk '$2==1 && $3=="chromium" {print $1}'); do kill $p; done`).
