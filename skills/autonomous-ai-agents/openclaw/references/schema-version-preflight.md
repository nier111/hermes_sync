# Database schema preflight — why the CLI refuses to start

Depth for pitfall 6 in SKILL.md. Two independent schema counters guard OpenClaw's SQLite
databases, and a build refuses to open any DB whose schema is NEWER than what it supports.

## The two counters

| Counter | Database | Scope |
|---|---|---|
| shared state schema | `~/.openclaw/state/openclaw.sqlite` (cron, tasks, channel bindings) | all agents |
| per-agent schema | `~/.openclaw/agents/<agent>/agent/openclaw-agent.sqlite` (sessions, board) | one agent |

They bump on separate upstream commits, so a build can be caught up on one and behind on the
other. "The CLI is up to date" is never a single fact — check both.

Read what is actually on disk; never infer it from a version string:

```bash
sqlite3 ~/.openclaw/state/openclaw.sqlite "PRAGMA user_version;"
sqlite3 ~/.openclaw/agents/main/agent/openclaw-agent.sqlite "PRAGMA user_version;"
```

From Python, while a gateway is live, open read-only so inspection can never write to a DB the
gateway owns:

```python
import sqlite3
with sqlite3.connect("file:/home/sato/.openclaw/state/openclaw.sqlite?mode=ro", uri=True) as c:
    print(c.execute("PRAGMA user_version").fetchone()[0])
```

A `-wal` / `-shm` pair beside the DB plus a moving mtime means the DB is in active use — the
gateway owns it, so stay read-only.

## Which commands check, which only look fine

- `--version` prints and exits without opening the DBs. A passing `--version` is **not** evidence
  the install is healthy; it is evidence only that the launcher runs.
- `doctor`, `status` and agent calls do open them and abort with a preflight/schema error naming
  both the DB's version and the build's supported version. Probe with one of these instead.
- The printed version label, git HEAD and what the built `dist/` actually supports are three
  separate things: a source checkout reports its git HEAD even when its built output is older.
  Read the build's declared supported versions from its own schema-contract module / package
  metadata rather than inferring from a version string.

## The dangerous divergence: gateway alive, CLI dead

An already-running gateway holds the schema assumption it loaded at startup in memory. If the DBs
are migrated forward underneath it, the gateway keeps serving — channels stay connected and the
bot keeps replying — while every newly spawned CLI subcommand dies on the DB open.

So "the bot still answers" does not mean the install works, and "the CLI is broken" does not mean
the gateway is down. Check both, in one call:

```bash
ps -eo pid,lstart,etime,cmd | grep 'dist/index.js gateway' | grep -v grep
cd ~/projects/openclaw && pnpm openclaw doctor 2>&1 | head -20
```

Expect the split to persist until the gateway is restarted on a compatible build — a restart is
the moment the in-memory assumption is re-read from disk.

## An update can abort AFTER migrating the DB

The updater may migrate a DB forward and only then hit the schema gate, aborting as "could not
start the CLI" — which reads like a no-op rather than a half-applied migration. The result is a DB
newer than the build: exactly the state the CLI will not start from.

Rules that follow:

- Never report "the update ran" from the fact that the update command was issued. Re-read both
  counters and the target's HEAD/version afterwards, and say plainly if it failed.
- A refusal message is a failure report even when the updater's own log shows no error, and even
  when a delegated agent reports success — that is a self-report, not evidence.
- Snapshot the DBs (or the whole state dir) before an update attempt. The state dir keeps
  timestamped `*.bak-<ts>` siblings; the per-agent DB has no automatic backup, so it is the one
to copy by hand.

## Recovering

The refusal itself names the two supported paths: run a build that supports this schema or newer
against this state dir, or point this build at a different state dir. Hand-editing `PRAGMA
user_version` downward is not one of them — the newer schema's tables and its migration ledger
came with the bump, and the old build cannot reconstruct them.

A stale source checkout can be tens of thousands of first-parent commits behind, so "pull and
rebuild" is a deliberate decision made with a backup in hand, not a routine step. To find which
upstream change raised a counter, and how far back it sits:

```bash
git log --oneline -S OPENCLAW_STATE_SCHEMA_VERSION origin/main
git rev-list --count HEAD..origin/main --first-parent
```
