---
name: hermes-cross-machine-sync
description: "Sync Hermes memory/skills across machines via a git repo."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, memory, sync, git, multi-machine, cron, backup]
---

# Hermes Cross-Machine Memory Sync

Keep Hermes long-term memory (`memories/`) and procedural memory (`skills/`) identical across two or more machines by tracking them in a private git repo. Built and end-to-end verified on a Linux laptop ↔ Windows desktop pair; the git side is OS-agnostic.

## When to use
- User wants "one me, two bodies": same memory/skills on multiple machines
- Setting up automatic backup of memory/skills to GitHub
- Re-verifying the sync after any edit to the sync script or .gitignore

## Architecture
- git repo ROOTED AT `$HERMES_HOME` (~/.hermes) — not a separate repo dir. A whitelist `.gitignore` makes `git add -A` safe there.
- Tracked: `memories/` (MEMORY.md + USER.md), `skills/`, `.gitignore` itself. Everything else ignored (secrets, sessions, logs).
- Sync script: `pull --rebase --autostash` → `add -A` → commit if changed → push. Silent (no stdout) when nothing changed — watchdog-friendly for `no_agent` cron.
- Schedule: Hermes cron, every 30 min, `no_agent=true`, script-only, `deliver=local`.
- NEVER track: `.env`, `auth.json`, `state.db`, `sessions/`, `.ssh` — secrets + live SQLite.

## Setup steps
```bash
# 1. Whitelist .gitignore (see templates/gitignore.whitelist)
# 2. Init + first commit
cd ~/.hermes && git init -b main
# 3. Copy templates/sync-memory.sh to ~/.hermes/scripts/sync-memory.sh, chmod +x
# 4. Create the REMOTE first (browser / gh repo create / API) — git push does NOT create repos
# 5. git remote add origin git@github.com:<user>/<repo>.git && git push -u origin main
# 6. Verify: git ls-remote origin main + secret scan (below)
# 7. Cron: cronjob create, no_agent=true, script='sync-memory.sh' (BARE FILENAME),
#    schedule='every 30m', deliver='local'
```

## Second machine activation
1. `git clone git@github.com:<user>/<repo>.git` somewhere; copy `memories/` + `skills/` into that machine's `$HERMES_HOME`
2. Repeat steps 2, 5, 7 there (git init, remote, cron). Keep one machine as the primary writer to minimize conflicts; `--autostash` on pull absorbs mid-edit files.

## Verification (do this after ANY edit)
1. End-to-end: push, then `git ls-remote origin main` matches local HEAD; scan the committed tree:
   `git ls-tree -r --name-only HEAD | grep -cE '\.env|auth\.json|state\.db|sessions/|\.ssh'` → must be 0.
2. Sandbox behavior test: `bash <skill>/scripts/verify-memory-sync.sh [path-to-sync-script]` — builds an isolated fake HOME + local bare remote and asserts 4 behaviors: whitelist-no-leak, silent-on-no-change, commit+push on change, fail-with-error on unreachable remote.

## Pitfalls (all hit in real sessions)
1. **Stale `.env` GITHUB_TOKEN**: can 401 ("Bad credentials") while SSH still works. Verify access with `ssh -T git@github.com` FIRST; `gh auth status` is separate from SSH auth. Don't assume the token in `.env` is valid.
2. **`git push` does not create a GitHub repo** — unlike some platforms. Create it first (browser `github.com/new` with Private, `gh repo create --private`, or API).
3. **cronjob script path**: must be the BARE FILENAME relative to `~/.hermes/scripts/` (e.g. `sync-memory.sh`). Absolute paths are rejected with an error.
4. **Lock-file noise**: `memories/*.lock` / `USER.md.lock` get staged by the whitelist — re-ignore with `/memories/*.lock` and `/skills/**/*.lock` AFTER the `!` rules.
5. **Watchdog silence semantics**: for `no_agent=true` cron, EMPTY stdout = silent (nothing delivered); non-zero exit = error alert. Design the script: silent on no-change, short summary on success, message + exit 1 on failure.
6. **Sandbox test timing bug**: capture the "before" state (HEAD hash) BEFORE running the code under test. Sampling after the run compares new-vs-new and reports a false failure.
7. **`state.db` is SQLite (WAL)** — never let two machines write it live. Async git push/pull is the point; don't try realtime shared access.
8. **Don't run `git add -A` without the whitelist**: ~/.hermes contains API keys and session data; one wrong `git add -A` leaks everything to the remote. The whitelist is the safety rail — verify it (case A of the sandbox script) before every trust-the-repo moment.

## Support files
- `templates/sync-memory.sh` — known-good sync script (copy into ~/.hermes/scripts/)
- `templates/gitignore.whitelist` — whitelist .gitignore pattern (copy to ~/.hermes/.gitignore)
- `scripts/verify-memory-sync.sh` — sandbox verification of the sync script + whitelist; run after any edit

Related: `hermes-internals` skill (data layout), bundled `hermes-agent` (config/cron semantics).
