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

## Crash / partial-write corruption recovery (real incident, 2026-08-28 → 09-11)
Symptom: the 30m `no_agent` sync cron silently fails for weeks — every output file in
`~/.hermes/cron/output/<job_id>/` is identical and short, showing
`[sync] pull 失败(远端未配置或冲突)` with `exit 1`. The error text is misleading: the
remote is fine, the LOCAL repo is corrupt. Direct symptoms:
- `git status` → `error: object file .git/objects/xx/yyy is empty` + `fatal: bad object HEAD`
- `git fsck` → `invalid sha1 pointer <sha>` for `refs/heads/main`, `refs/remotes/origin/main`, `HEAD`
- `find .git/objects -type f -size 0` → N zero-length loose objects
- `tail .git/logs/HEAD` → last valid reflog line, then a NUL-padded tail (compare `cat -v`)
- mtimes of `.git/index`, `.git/refs/remotes/origin/main`, `.git/logs/*` all cluster at the same
  minute → write interruption (power loss / hard reset) rather than a git bug. Disk/inodes fine, so
  don't chase space.

Key check before repairing: `git ls-remote origin main` from a scratch dir. If the REMOTE tip equals
the sha your broken local ref points at, the lost objects are recoverable by re-fetch and nothing is
lost.

Repair (non-destructive, no `reset --hard` — the working tree is the live truth):
1. Back up metadata only: `cp -a .git/logs .git/refs .git/index .git/HEAD /home/$USER/git-repair-backup-$(date +%F)/`
   (don't copy the multi-GB pack; it's intact).
2. Read the last valid commit out of the reflog (`tail .git/logs/HEAD`) and confirm it is readable:
   `git cat-file -t <sha>` → `commit`, `git cat-file -p <sha>` → valid tree.
3. Delete the zero-length loose objects (`find .git/objects -type f -size 0 -delete`).
4. Truncate each reflog to the last newline BEFORE the first NUL byte (Python: `data[:data.rfind(b'\n',0,data.find(b'\x00'))+1]`),
   otherwise appends land after the NUL junk.
5. `rm -f .git/refs/remotes/origin/main` (broken pointer; fetch recreates it), then
   `git fetch origin main` → re-downloads the missing commit/tree/blobs.
6. Verify: `git fsck --no-progress` (silent), `git log --oneline -3`, `git rev-parse --short HEAD origin/main`
   (equal), `git status --short` (shows the real accumulated diffs).
7. Prove the pipeline end-to-end: run `bash ~/.hermes/scripts/sync-memory.sh` once — expect
   `[sync] 已提交 <sha> (N 个文件)` + `[sync] 已推送`, then confirm `git ls-remote origin main` matches
   local HEAD and `git status --short` is empty.

Notes: SSH (`git@github.com:...`) worked with no proxy even when HTTP(S) tooling needed 127.0.0.1:7890.
After repair, mention to the user the clustered mtime so they can check for a power event on that date.

## Pitfalls
- Only ever `git add -A` with the whitelist in place. Audit pushed tree: `git ls-tree -r --name-only HEAD | grep -E '\.env|auth\.json|state\.db|\.ssh'` must be empty.
- Fresh bare remote → first script run fails on pull; seed with an initial push.
- Files rewritten atomically by tools (Hermes MEMORY.md/USER.md) produce clean full-file diffs and rarely conflict; keep `*.lock` untracked.
- Verify scripts: capture before/after state OUTSIDE the script under test, or your verification harness becomes the thing that's wrong.
