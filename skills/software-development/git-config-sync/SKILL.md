---
name: git-config-sync
description: "Use when syncing a config dir via git (whitelist + cron)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
---

# Git-Based Config/Memory Directory Sync

Proven pattern for syncing chosen subdirs of a secret-heavy home/config dir (e.g. Hermes `memories/` + `skills/` inside `~/.hermes`, which also holds `.env`, `auth.json`, `state.db`, `sessions/`) to a private git remote.

## Whitelist .gitignore (track ONLY chosen dirs inside a secret-heavy root)
```
/*
!/memories/
!/memories/**
!/skills/
!/skills/**
!/.gitignore
/memories/*.lock
/skills/**/*.lock
```

## Sync script (silent-watchdog shape, cron-friendly)
1. `git pull --rebase --autostash origin main` — tolerate missing remote on first run only.
2. `git add -A` (whitelist makes this safe).
3. If `git diff --cached --quiet` → `exit 0` with NO stdout (silent = nothing to report for cron).
4. Else count changed files (`git diff --cached --name-only | wc -l`) BEFORE committing, commit with timestamp message, push.
5. Failures: message to stderr + `exit 1` (cron `no_agent` sends an error alert on non-zero exit).

## Cron wiring (Hermes)
- `cronjob create` with `no_agent=true`, `script=<filename only>` — relative to `~/.hermes/scripts/`; absolute paths are REJECTED. `deliver='local'`. Schedule e.g. `every 30m`.

## Sandbox verification (always do this before trusting a sync setup)
1. `TMP=$(mktemp -d /tmp/verify-XXXXXX)`; `export HOME=$TMP/home`; copy the REAL .gitignore + script into `$TMP/home/.hermes`.
2. `git init --bare $TMP/remote.git`; `git init -qb main`; add remote pointing at the bare repo; set a local git identity.
3. Seed: initial commit + push FIRST — a fresh bare remote has no refs, so the script's pull fails and it exits 1 on first run.
4. Test cases:
   - (a) Whitelist leak: drop `.env`, `auth.json`, `state.db`, `.ssh/*`, `*.lock` into the tree → `git add -A` → assert none staged (`git diff --cached --name-only | grep -E ...` empty).
   - (b) No-change run → exit 0, empty stdout.
   - (c) Append to a tracked file → run → exit 0, commit+push, remote HEAD advances. Capture `HEAD_BEFORE` BEFORE running the script (capturing after the run compares new-vs-new and falsely fails).
   - (d) Break the remote URL → exit 1 + error on stderr.

## Pitfalls
- Only ever `git add -A` with the whitelist in place. Audit pushed tree: `git ls-tree -r --name-only HEAD | grep -E '\.env|auth\.json|state\.db|\.ssh'` must be empty.
- Fresh bare remote → first script run fails on pull; seed with an initial push.
- Files rewritten atomically by tools (Hermes MEMORY.md/USER.md) produce clean full-file diffs and rarely conflict; keep `*.lock` untracked.
- Verify scripts: capture before/after state OUTSIDE the script under test, or your verification harness becomes the thing that's wrong.
