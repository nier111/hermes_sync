---
name: hermes-internals
description: Use when asked about Hermes data layout or channel status.
---

# Hermes internals — data layout, channel forensics & programmatic usage accounting

Answers "where is X stored?", "is channel Y actually connected?", and "how much context/cost is this session using?" about Hermes itself. Distinct from the bundled `hermes-agent` skill (that covers using/configuring the CLI); this is about the on-disk data, channel liveness, and CLI-surface accounting flags you can drive from another process.

## Where things live (~/.hermes/)
- `config.yaml` — settings; `platform_toolsets` maps platform → toolset (e.g. `qqbot: [hermes-qqbot]`)
- `state.db` — PRIMARY session store: ALL sessions (CLI, TUI, gateway) plus `gateway_routing`. `hermes sessions list` reads this. Two tables answer billing/model questions: `sessions` (has `model`, `model_config`, `input_tokens`, `output_tokens`, `actual_cost_usd`, `started_at`, `last_activity_at`) and `session_model_usage` (per-session × per-model × per-billing-provider token/cost rollups — THE ground truth for "which model did this session actually consume").
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

## Programmatic usage accounting (for external callers)

When integrating Hermes into another app (e.g. a multi-agent UI that shells out to `hermes -z`), get usage numbers without parsing chat output:

- `hermes -z "<prompt>" --usage-file /tmp/usage.json` — one-shot mode only; after the run writes a JSON report: `input_tokens`, `output_tokens`, `reasoning_tokens`, `total_tokens`, `estimated_cost_usd`, `api_calls`, `model`, `provider`, `session_id`. Written even when the run fails, so pipelines can always account for spend. No effect outside `-z`/`--oneshot`.
- `hermes prompt-size` — system-prompt cost breakdown (bytes/chars): skills index, memory, user profile, tool schemas, per-toolset size. Judge fixed overhead before any conversation.
- `hermes -z` is a FRESH process every call — no session state, so it re-sends the full system prompt + memory + skills index + tool schemas + the entire prompt each time. Continuity must be supplied by the caller (pass prior turns inside the prompt).
- In-session `/usage` and `/context` print live numbers; the percentage is `last_prompt_tokens / context_length` (context-window occupancy, computed in `cli.py`), NOT cumulative spend. Cumulative spend is `session_total_tokens` (`/usage`).

## Which model actually consumed tokens (billing forensics)
To answer "did X spend flash/pro?", NEVER infer from `config.yaml` `model.default` (it only says what a NEW session WOULD default to — the user may override per session, and cron jobs may pin their own model). Query the ground truth:
```sql
sqlite3 -header -column ~/.hermes/state.db \
  "SELECT datetime(last_activity_at,'unixepoch','localtime') t, substr(id,1,16) sess, model, message_count, input_tokens, output_tokens, actual_cost_usd
   FROM sessions WHERE last_activity_at > strftime('%s','now','-2 days') ORDER BY last_activity_at DESC;"
sqlite3 -header -column ~/.hermes/state.db \
  "SELECT datetime(last_seen,'unixepoch','localtime') t, model, billing_provider, api_call_count, input_tokens, output_tokens
   FROM session_model_usage WHERE last_seen > strftime('%s','now','-2 days') ORDER BY last_seen DESC;"
```
Per-profile bots have their OWN db at `~/.hermes/profiles/<name>/state.db` — check it before attributing spend to that bot. Config `default=flash` ≠ the bot ran today; last_activity_at/last_seen tells you if it even fired.

## Pitfalls
- When the user says "the qqbot / the bot" on a machine with BOTH Hermes and OpenClaw deployed, check BOTH `~/.hermes` and `~/.openclaw` — each has a qqbot; only one is live (see the `openclaw` skill for the other side).
- Grepping config.yaml for credentials finds nothing: provider creds live in `auth.json`, channel creds in the gateway's own store.
- `sessions.json` looks like a session list but is a mirror — use `state.db` / `hermes sessions list` for the real list.
