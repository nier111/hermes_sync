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

Call it directly: `curl -X POST http://127.0.0.1:18789/api/chat -H 'Content-Type: application/json' -d '{"message":"..."}'`

## Pitfalls

- **Mid-update mixed state**: while `openclaw update --yes` runs, disk `dist/` files are newer than the running process → API returns 404 for routes the frontend knows. Wait for restart before relying on the API.
- Updates run through a local proxy if configured (env `HTTPS_PROXY=http://127.0.0.1:7890` etc. in the update process cmdline) — mirror it when you need outbound network for OpenClaw tooling.
- `~/.openclaw/memory/main.sqlite` being tiny (a handful of chunks) is normal — OpenClaw leans on session files for context.
- Persona/personality files (if any) are plain markdown under `workspace/memory/`, not wired into `openclaw.json`; check there when asked about OpenClaw's "人格"/persona.
