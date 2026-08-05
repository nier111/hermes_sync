---
name: hermes-internals
description: Use when asked about Hermes data layout or channel status.
---

# Hermes internals — data layout & channel forensics

Answers "where is X stored?" and "is channel Y actually connected?" about Hermes itself. Distinct from the bundled `hermes-agent` skill (that covers using/configuring the CLI); this is about the on-disk data and how to prove a channel is live.

## Where things live (~/.hermes/)
- `config.yaml` — settings; `platform_toolsets` maps platform → toolset (e.g. `qqbot: [hermes-qqbot]`)
- `state.db` — PRIMARY session store: ALL sessions (CLI, TUI, gateway) plus `gateway_routing`. `hermes sessions list` reads this.
- `sessions/sessions.json` — LEGACY MIRROR of the routing index only (its own `_README` says so); NOT the session list. Don't quote it as the source of truth.
- `sessions/request_dump_*.json` — failed-request dumps (e.g. `non_retryable_client_error` with full request body) — useful for diagnosing provider errors
- `memories/MEMORY.md` — long-term memory (the `memory` tool's target); SEPARATE from session history
- `logs/{gateway,agent,errors}.log` — full message-flow trace
- `channel_directory.json` — registered channels per platform (id/name/type/thread_id)
- `auth.json` — provider credentials (deepseek/openrouter/...), keyed by provider
- Platform sources: `~/.hermes/hermes-agent/gateway/platforms/<name>/` (e.g. `qqbot/`: adapter.py, onboard.py, crypto.py)

## Proving a channel is ACTUALLY connected
Presence of `qqbot:` under `platform_toolsets` is TEMPLATE config, NOT proof of connection. Verify with:
1. `channel_directory.json` has an entry for the platform
2. `logs/gateway.log` shows: `Connecting to <platform>...` → `✓ <platform> connected` → `Ready, session_id=...`
3. Live traffic lines: `inbound message: platform=qqbot user=... chat=... msg='...'` and `response ready: platform=... time=...s api_calls=N response=N chars`

## Session ↔ channel identity
- Session key format: `agent:main:<platform>:<type>:<id>` — e.g. `agent:main:qqbot:dm:83ECED7607DD4DC378B441144891D01D`
- Cross-check channel: session `created_at` (sessions.json / state.db) vs the `inbound message` timestamp in gateway.log — they should match to the second.

## qqbot platform notes (Tencent QQ official Bot API)
- Credentials: `QQ_APP_ID` / `QQ_CLIENT_SECRET`, stored via the gateway (NOT in config.yaml — grepping config for keys finds nothing)
- Connection: websocket `wss://api.sgroup.qq.com/websocket`, C2C (single-chat) messages
- Onboarding warning `Failed to create bind task: Invalid port: '127.0.0.1:7891'` is NON-FATAL (bind-task misconfig; connection unaffected)

## Pitfalls
- When the user says "the qqbot / the bot" on a machine with BOTH Hermes and OpenClaw deployed, check BOTH `~/.hermes` and `~/.openclaw` — each has a qqbot; only one is live (see the `openclaw` skill for the other side).
- Grepping config.yaml for credentials finds nothing: provider creds live in `auth.json`, channel creds in the gateway's own store.
- `sessions.json` looks like a session list but is a mirror — use `state.db` / `hermes sessions list` for the real list.
