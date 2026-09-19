---
name: openclaw
description: Use when calling the local OpenClaw agent gateway. 中文/被墙搜索优先OpenClaw(--agent main);用户明确让用OpenClaw时先加载本skill。
---

# OpenClaw (local agent gateway)

OpenClaw (Clawdbot's open-source successor) runs as a Node gateway on this machine. Hermes can call it over its localhost HTTP API or its CLI. This skill covers locating it, checking health, discovering its API, and driving it.

## Disambiguation — TWO agent deployments on this machine
- **Hermes (me)**: data in `~/.hermes` (own config, sessions, memories, logs)
- **OpenClaw**: data in `~/.openclaw`, project `~/projects/openclaw`, gateway `:18789`
- "qqbot" exists in BOTH: OpenClaw's `~/.openclaw/qqbot/` is credentials-ONLY (no chat content); Hermes has a live connected QQ bot. When the user says "the qqbot" / "the bot", check BOTH deployments and report which one actually has content — investigating the wrong one wastes a full round of tool calls.
- **"更新你" / "update yourself" means HERMES, not OpenClaw.** The update target is `~/.hermes/hermes-agent` (`hermes update`); `~/projects/openclaw` is a separate project. OpenClaw's role is to *execute* commands on Hermes' behalf (that agent is called Tomoya) — it is never the object of "update your own framework". Acting on that request with `pnpm openclaw update` changes nothing about Hermes and can leave OpenClaw's own DBs newer than its build, i.e. its CLI stops starting while its gateway keeps serving (pitfall 6).
- **Updating OpenClaw itself is `git pull` + `pnpm build`, not `openclaw update`.** The checkout is a git install: pull `origin/main`, rebuild, done. `openclaw update` is a package-release path that has been failing on this box (pitfall 7) and the user has never used it — don't propose it as the update plan, and only reach for it if the user asks for it by name.
- **Name the absolute target path and the exact command in any delegated task.** A subagent executes in the project it lives in, so "run the update" handed to OpenClaw silently becomes an OpenClaw self-update. Before delegating, state the target directory, the exact command, and what is off-limits ("read-only, do not update yourself").

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

## Delegating Chinese Web Research to OpenClaw

OpenClaw's browser/search is stronger against Chinese anti-scraping than Hermes's. When you need authoritative Chinese sources (百度百科/知乎/贴吧) or hit repeated captchas/412s, delegate the search to OpenClaw instead of flailing across sites. It found 百度百科/知乎 sources for meme lookups (e.g. 老吴、耄耋、打窝仙人) that direct curl/browser attempts couldn't reach, and it flags uncertainty with `(?)` instead of hallucinating. Call: `pnpm openclaw agent --agent main -m "search <topic> on 百度百科/知乎, cite sources"`.

## Pitfalls
0. **联网搜索卡住/超时（症状：CLI `timeout` exit 143，或长时间无输出）**：根因通常是
   搜索后端 DuckDuckGo Lite 被墙/超时，**不是 gateway 挂了**。先看日志定位子系统，
   再 `systemctl --user restart openclaw-gateway.service` 恢复，别只诊断不修复。
   完整诊断表、重启细节、fallback 机制见 `references/search-hang-diagnosis.md`。
1. **Update/restart mixed state.** `openclaw update --yes` unpacks new dist files while the OLD gateway keeps running. In that window, the on-disk bundle advertises routes the running process 404s on — the API looks broken but isn't. Diagnose: compare `stat -c %y dist/index.js` (new) against the gateway process start time (old); check for a running `openclaw-update` process. Don't call the API mid-update; wait for the restart (a `gateway-supervisor-restart-handoff.json` in `~/.openclaw` signals the handoff).
2. **Secrets.** Config may hold provider keys without a plain `apiKey` field. Never dump the config raw — redact with sed when grepping.
3. Don't run CLI commands while an update holds the pnpm store lock.
4. **`/tmp` is a small tmpfs (~3.8G) and the update preflight alone uses ~2.5G.** Mid-update, writes to /tmp fail with `OSError: [Errno 122] Disk quota exceeded` while `df -h /` looks fine (and a sqlite3 redirect-to-file can silently produce 0 bytes). Check `df -h /tmp` before using /tmp; write outputs to the home dir instead. After the update finishes, offer to clean `/tmp/openclaw-update-preflight-*`.
5. **`read_file` misdetects Chinese/emoji-heavy UTF-8 markdown as binary** (reports "Binary file" and returns empty). Confirm with `file` (it says "Unicode text, UTF-8") and read via `cat` — applies to persona/memory files in `workspace/memory/`.
6. **A DB schema newer than the build makes the CLI refuse to start while the gateway keeps working.** Two independent counters guard the shared state DB and each agent DB; `--version` bypasses both, while `doctor` / `status` / agent calls abort with a schema-preflight error naming both versions. An already-running gateway keeps the schema assumption it loaded at startup in memory, so the channel bot still replies while every freshly spawned CLI subcommand dies — "the bot answers" is not "the install is healthy". The updater can also migrate a DB forward and only then abort on the gate, which reads as a refusal rather than a completed update: never report "update ran" from the fact that the command was issued, re-read the DB versions and the target's HEAD afterwards. Depth: `references/schema-version-preflight.md`.
7. **`openclaw update` fails on this box at `validating — preflight worktree` — don't burn a session debugging it; update via `git pull` + `pnpm build`.** Every retry dies the same way: `error: unable to write file` on a handful of `ui/vite.config.ts`-style files, then `fatal: Could not reset index file to revision 'HEAD'`. A `GIT_TRACE=1` run shows the stage's shape: it clones the repo into a throwaway bare repo under `/tmp/openclaw-git-admission-*/repository.git` and points `git worktree add --detach` at a path INSIDE that git-dir — on a ~3.8G `/tmp` tmpfs the same stage also wants ~553MB of snapshot space on. Two further traps if you do run it: the candidate commit is resolved from the `linux-stable` tag, so a tag that isn't fetched locally makes the worktree step report `invalid reference` until `git fetch --tags`; and the command is a *shared-installation* exclusive — any leftover updater process from an earlier attempt holds the lease and new runs abort with `Another update executor owns this installation`. That message is a claim, not proof the other run is live: check the pid/start time before killing anything.
8. **Killing a stale updater: never `pgrep -f openclaw-update` with the literal pattern.** The pattern text sits in your own shell's command line, so pgrep matches the shell running the command and the kill lands on your own call (symptom: the terminal call returns exit `-9` while the target processes look untouched). Use the bracket trick — `pgrep -f '[o]penclaw-update'` — or read pids from `ps -eo pid,ppid,args` and filter them in awk.

## Verification
Run `scripts/probe.sh` before relying on the API — it prints gateway pid/start time, port state, whether an update is in flight, dist-vs-process age, and key endpoint HTTP codes.
