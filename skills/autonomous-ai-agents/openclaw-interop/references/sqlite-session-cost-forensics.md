# OpenClaw 2026.8+ SQLite session and cost notes

After the 2026.8 migration, live conversations may no longer exist under `agents/<agent>/sessions/*.jsonl`.

## Current locations

- Agent DB: `~/.openclaw/agents/<agent>/agent/openclaw-agent.sqlite`
- Session metadata: `session_nodes`, `session_windows`
- Raw events: `transcript_events(event_json, session_id, seq)`
- Search text: `session_transcript_fts`
- Gateway/cron operational DB remains separate at `~/.openclaw/state/openclaw.sqlite`

Assistant message events can contain `message.usage` with `input`, `output`, `cacheRead`, `cacheWrite`, `reasoningTokens`, `totalTokens`, and nested `cost.total`. Aggregate all assistant usage objects in the target session; count `toolResult` events by `toolName` to explain tool-loop amplification.

Read the live SQLite DB so WAL changes are visible. Legacy JSONL may survive only in `session-sqlite-import-archive/`.

## Cost-aware diagnosis lesson

Each tool result or process poll can cause another model invocation with the growing context. For node matrices or repeated reachability probes, execute one bounded script that loops, aggregates, and restores the original state. Do not use dozens of agent-mediated process polls.

A CLI-only Cloudflare 403/404 is bot-detection evidence, not proof that the user's real browser, account, region, or proxy exit is blocked. Confirm with a real browser and repeat after a short observation window before declaring a persistent outage.
