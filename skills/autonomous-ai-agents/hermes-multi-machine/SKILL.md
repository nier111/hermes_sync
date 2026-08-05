---
name: hermes-multi-machine
description: "Run Hermes on several machines or sync memory/skills."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, multi-machine, sync, memory, git, ssh]
---

# Hermes Multi-Machine

Deploying Hermes on more than one machine and keeping memory/skills in sync. Covers architecture facts, the git-sync recipe (this user's chosen approach), the SSH execution backend, and cross-session message retrieval.

## Architecture facts

- No "single body" limit: Hermes is ordinary software — install it on as many machines as you want. Each install is fully independent (own config, sessions, skills, memory) unless you sync.
- Windows is supported natively (WSL2 recommended for bash toolchains). SSH backend and desktop app let one instance drive another.
- "One me, two bodies" (shared memory) requires sync — it does NOT happen by default.

## Connection modes (pick per need)

| Mode | Setup | Use when |
|---|---|---|
| A. Second independent install + sync | Install on machine 2, git-sync memories/skills | Desktop needs to work standalone |
| B. SSH execution backend | `terminal.backend: ssh` + env `TERMINAL_SSH_HOST/USER/PORT/KEY`; OpenSSH Server + pubkey on remote | Occasional heavy tasks; single memory store; zero sync |
| C. Agent-to-agent | ACP server / MCP over network | Deep interop between the two agents |

## Git memory-sync recipe (user-approved)

1. **Private repo is mandatory** (memory holds personal data). Create via `gh` or browser. SSH-key auth to GitHub works without `gh auth login` — verify with `ssh -T git@github.com` first.
2. `git init -b main` inside `~/.hermes` with a **whitelist** `.gitignore` tracking ONLY `memories/` and `skills/` — see `templates/gitignore-whitelist`. Never track `.env`, `auth.json`, `state.db`, `sessions/`, `*.lock`. Prove no-leak with `git ls-tree -r --name-only HEAD | grep -E '\.env|auth\.json|state\.db'`.
3. Sync script = silent watchdog (`scripts/sync-memory.sh`): `git pull --rebase --autostash` → `git add -A` → commit only if changed → push. **Silent (exit 0, no output) when nothing changed**; error + exit 1 on failure — this matches cron `no_agent` semantics (empty stdout = nothing delivered).
4. Schedule: `cronjob` action=create, `no_agent=true`, `script=sync-memory.sh` (path **relative to `~/.hermes/scripts/`** — absolute paths are rejected), `deliver=local`, `every 30m`.
5. Second machine: clone repo, copy `memories/` + `skills/` into its `~/.hermes`. Never share `state.db` live across machines (SQLite concurrent-write locks); async one-way sync only.
6. Conflicts: `pull --rebase --autostash` handles almost everything; memory files are single-writer in practice. If a conflict ever appears, resolve by keeping the newer file.

## Verification

Run the sandbox verifier before trusting the setup (`scripts/verify-sync-sandbox.sh`): builds a fake `~/.hermes` with planted `.env`/`auth.json`/`state.db`/`*.lock`, a local bare remote, and asserts: whitelist leaks nothing, no-change run is silent, change run commits+pushes (remote HEAD moves), unreachable remote fails with exit 1.

## Cross-platform message retrieval

Messages sent to you on another platform (e.g. QQ) land in THAT platform's session, not the current CLI session — retrieve them from `~/.hermes/state.db` (see `references/state-db-message-extraction.md`).

## Pitfalls

- `~/.hermes` is actively written by the gateway; whitelist `.gitignore` is what keeps the repo clean — never switch to blacklist style.
- `hermes cronjob` script paths must be relative to `~/.hermes/scripts/`.
- Memory files are atomic-replaced whole files — ideal git targets; keep them small.
- /tmp is often tmpfs (RAM) and can fill up (e.g. a 2.5G OpenClaw update preflight) — check `df -h /tmp` before writing extracted data there; write to home instead.
