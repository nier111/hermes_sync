---
name: openclaw
description: Use when calling the local OpenClaw agent gateway.
---

# OpenClaw (local agent gateway)

OpenClaw (Clawdbot's open-source successor) runs as a Node gateway on this machine. Hermes can call it over its localhost HTTP API or its CLI. This skill covers locating it, checking health, discovering its API, and driving it.

## Disambiguation — TWO agent deployments on this machine
- **Hermes (me)**: data in `~/.hermes` (own config, sessions, memories, logs)
- **OpenClaw**: data in `~/.openclaw`, project `~/projects/openclaw`, gateway `:18789`
- "qqbot" exists in BOTH: OpenClaw's `~/.openclaw/qqbot/` is credentials-ONLY (no chat content); Hermes has a live connected QQ bot. When the user says "the qqbot" / "the bot", check BOTH deployments and report which one actually has content — investigating the wrong one wastes a full round of tool calls.

## Key locations
- Project: `~/projects/openclaw` (`dist/` holds the bundled gateway + control-UI frontend)
- Config: `~/.openclaw/openclaw.json` (auth profiles, models, channels; `.bak*`/`.last-good` siblings exist)
- State dir: `~/.openclaw/` (agents, memory, `logs/`, cron, tasks, workspace)
- Gateway: `http://127.0.0.1:18789` — web control UI at `/docs` (also `/swagger`)
- CLI: `pnpm openclaw ...` (binary at `~/projects/openclaw/node_modules/.bin/openclaw`)

## Storage layout (what lives where — verified 2026-08)
| Path | Contains |
|---|---|
| `~/.openclaw/agents/<agent>/sessions/*.jsonl` | full conversation transcripts (trajectory JSONL, plain text), one per session; `.deleted`/`.reset` suffixes = rotated files |
| `~/.openclaw/memory/main.sqlite` | semantic memory: `chunks` + embeddings (e.g. nomic-embed-text via local ollama). Often nearly empty — that's normal |
| `~/.openclaw/state/openclaw.sqlite` | operational state (`cron_jobs`, `task_runs`, channel bindings) — NOT chat content |
| `~/.openclaw/qqbot/` | channel CREDENTIALS only (`credential-backup.json`) — no conversations |
| `~/.openclaw/openclaw.json` | config; usually NO top-level `apiKey` |
| `~/.openclaw/workspace/` | agent working files (can be hundreds of MB) |

**Memory ≠ chat history**: low chunk count in the memory DB does NOT mean no conversations happened — transcripts live in `agents/<agent>/sessions/`. To see which channels carried traffic: `for f in ~/.openclaw/agents/*/sessions/*.jsonl; do grep -o '"messageChannel":"[a-z]*"' "$f" | head -1; done | sort | uniq -c`.

## Status check
```bash
ps -eo pid,lstart,etime,cmd | grep -E "dist/index.js gateway" | grep -v grep   # gateway proc
ss -tln | grep 18789                                                           # port listening
ps -eo pid,etime,cmd | grep -E "openclaw (update|updater)" | grep -v grep      # update running?
```

## API discovery
The control UI is an SPA whose router 404-fallbacks to the app, so blindly probing unknown paths is useless. Real routes live in the frontend bundle — grep the dist files:
```bash
cd ~/projects/openclaw/dist && grep -rhoE '"/api/[a-zA-Z0-9/_:{}.$-]+"' *.js | sort -u
```
Known endpoints (found in bundle):
- `POST /api/chat` — chat with the agent
- `POST /api/v1/rpc` — JSON-RPC transport (what the CLI itself uses)
- `GET /api/me`, `GET /api/messages`, `POST /api/prompt`, `GET /api/v1/models`

**2026.7.2+ (verified 2026-08-06): HTTP API now requires auth.** `/api/chat` was removed (404), `/api/channels` returns 401, and the token flow lives in the frontend bundle — no plain `apiKey` in config. Don't fight the HTTP API; use the CLI below (it handles auth internally).

## Calling it
- CLI (reliable, handles auth): `export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH" && cd ~/projects/openclaw && pnpm openclaw agent --agent main -m "message" [--json]`
  - `--agent <id>` required (list: `pnpm openclaw agents list`); `--deliver` sends the reply to a channel, `--channel qqbot` targets QQ.
  - `ask`/`chat` are NOT present in 2026.7.2's CLI — use `agent` (or `message` subcommand).
  - PATH prefix is mandatory: Hermes terminal env is a per-command snapshot, so `nvm use` doesn't persist and the next call falls back to old node (fails the engines gate). `nvm alias default 22.22.3` once for interactive shells.
- Config hints: `auth.profiles` lists providers (moonshot / openrouter / minimax / kimi / deepseek); channels: telegram / discord / slack / whatsapp / qqbot. Updates route through local proxy `127.0.0.1:7890`.

## Pitfalls
1. **Update/restart mixed state.** `openclaw update --yes` unpacks new dist files while the OLD gateway keeps running. In that window, the on-disk bundle advertises routes the running process 404s on — the API looks broken but isn't. Diagnose: compare `stat -c %y dist/index.js` (new) against the gateway process start time (old); check for a running `openclaw-update` process. Don't call the API mid-update; wait for the restart (a `gateway-supervisor-restart-handoff.json` in `~/.openclaw` signals the handoff).
2. **Secrets.** Config may hold provider keys without a plain `apiKey` field. Never dump the config raw — redact with sed when grepping.
3. Don't run CLI commands while an update holds the pnpm store lock.
4. **`/tmp` is a small tmpfs (~3.8G) and the update preflight alone uses ~2.5G.** Mid-update, writes to /tmp fail with `OSError: [Errno 122] Disk quota exceeded` while `df -h /` looks fine (and a sqlite3 redirect-to-file can silently produce 0 bytes). Check `df -h /tmp` before using /tmp; write outputs to the home dir instead. After the update finishes, offer to clean `/tmp/openclaw-update-preflight-*`.
5. **`read_file` misdetects Chinese/emoji-heavy UTF-8 markdown as binary** (reports "Binary file" and returns empty). Confirm with `file` (it says "Unicode text, UTF-8") and read via `cat` — applies to persona/memory files in `workspace/memory/`.

## Verification
Run `scripts/probe.sh` before relying on the API — it prints gateway pid/start time, port state, whether an update is in flight, dist-vs-process age, and key endpoint HTTP codes.
