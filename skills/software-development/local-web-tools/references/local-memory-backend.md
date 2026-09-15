# Adding an agent-readable memory backend to a local web tool

When the tool is a drill/tracker, the user will eventually want follow-up work done *on his own data*:
"针对不认识的词做拼写训练". A `localStorage`-only tool cannot support that — the agent has no way to read it.
Retrofitting is cheap only while the dataset is small; build it in-session instead.

Reference implementation: `~/projects/yao-vocab-sieve/server.py` (added 2026-09, 186 items deep).

## Why browser-only is a dead end

With `python3 -m http.server`, the only trace of the user's work is the request log:

```text
GET /index.html 200
GET /src/app.js 200
GET /data/words.json 200
```

No answers, no ratings, nothing about the item. So the honest answer to "你那边后台能看见我的答题记录吗"
is "no — the records live in Chromium's localStorage and never leave it". Verify this from the actual data flow
before answering; never infer visibility from the fact that you built the thing.

Also note the ceiling of the client-side history list: a UI that keeps only the last 100 operations for an undo
buffer loses older *events* even though per-item final state survives. Say which is which when reporting.

## Server shape (stdlib only)

`server.py`: subclass `http.server.SimpleHTTPRequestHandler` with `directory=ROOT`, and intercept the API paths
before delegating to the static handler. One process serves the page and the data — no second port, no framework,
`--host 127.0.0.1` default.

```text
GET    /api/summary   -> counts per bucket, cursor/round/phase, the list needing work
GET    /api/state     -> full snapshot for the UI to restore from
PUT    /api/state     -> bulk replace (used by import / reset / first sync)
POST   /api/attempt   -> one rating event (append-only history + item state update)
DELETE /api/state     -> clear (used by tests and the UI reset button)
```

Keep the store in a small class (`StudyStore`) with the SQLite connection owned by one lock; the browser is a
*single* writer in practice, but a background sync from the page can overlap with a keystroke.

## SQLite layout that answers the real questions

Two tables: one row per item (`word_id` PK, bucket/status, times seen, last rating, consecutive-known streak,
first/last answered timestamps, round) and an append-only `attempts` history. The streak column is what later
drives "which words still need work", so persist it rather than recomputing from a truncated history.

## Lossless migration from localStorage

Migration runs **once**, on first load of the new frontend, and must never cost the user work he already did:

1. Frontend detects that the API reports an uninitialized/empty store but `localStorage` has state.
2. It `PUT`s the whole browser snapshot.
3. Server records the import and writes a **timestamped backup JSON** of the raw payload first
   (`~/.local/share/<tool>/backups/browser-state-<ts>.json`) — before any rows are touched.
4. Subsequent loads are normal dual-write; migration must be idempotent.

Verify the chain explicitly instead of trusting it: seed N items → migrate → answer one more (N+1) → undo → back
to N, with every bucket count unchanged. Do this in a scratch DB *and* with the real browser profile.

## Where the DB lives (privacy)

```text
~/.local/share/yao-vocab-sieve/study.db          # XDG_DATA_HOME, NOT under the served root
~/.local/share/yao-vocab-sieve/backups/*.json
```

Old location was `<project>/data/study.db`, which the static handler would happily serve over HTTP — a silent
undo of the reason a local tool was chosen. Also remove the staging copies a migration leaves behind
(`data/browser-state-migration.json`, scratch LevelDB copies, temp test DBs/profiles in `/tmp`).

## Verification checklist

- `python -m unittest tests/test_server.py` for store-level tests (attempt updates only the answered item,
  summary exposes the words that need work, sync imports browser state without losing progress) — run it from
  the same `npm test` script as the node tests: `"test": "node --test tests/*.test.mjs && python -m unittest tests/test_server.py -v"`.
- Cross-check two independent read paths after migrating — API response vs a direct `sqlite3` query
  (`select status,count(*) from word_progress group by status`) plus `state_meta`. They must agree exactly.
- Restart the unit and confirm `systemctl --user show <unit> -p ExecStart` now points at `server.py --host … --port …`.
- Kill background servers started for testing, and delete the temp DB/profile, before reporting.
- Report the buckets in a table (already-swept / known / fuzzy / unknown / remaining / needs-work) so the user can
  see the migration preserved his numbers.

## Pitfall: the stale tab

A page already open from the previous version keeps running the old JS with no API calls and no errors — it
looks like the backend is broken. Bump the query (`/?v=4`), open it yourself, and tell the user to close the old
tab. The launcher URL stays the same, so only the deliberate open signals the update.
