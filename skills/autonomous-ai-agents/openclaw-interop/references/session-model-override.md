# Session-level model override: why `openclaw.json` routing edits do nothing

Companion to `references/model-routing-and-auth-store.md`. Read that one for where the
config pieces live and how to edit them; read THIS one before concluding a routing edit
"didn't work". Observed 2026-09-19 on the Aoi/Tomoya QQ setup.

## The failure mode

`agents.defaults.model.primary` / `.fallbacks` can be **completely inert** because a
**per-session override** is stored in the *agent* database and wins over the defaults.
Config edits, hot reloads, and restarts all silently keep serving the pinned model.

Symptom chain — any two of these together mean session override, not a config bug:

```
agent model: deepseek/deepseek-v4-flash (thinking=high, fast=off)   <- startup READ the config fine
...
model-fetch start provider=kimi api=anthropic-messages model=kimi-for-coding   <- runtime serves another provider
model-fallback ... fallbackConfigured:false                        <- configured fallbacks inert
HTTP 403 {"type":"permission_error","message":"You've reached your 5-hour usage limit..."}
```

**The tell:** the startup log and the runtime log disagree about the model. That proves the
config file IS being read, so a *later* layer rewrites the model. Stop re-checking
`openclaw.json` and go read the session rows.

Related false lead from the same session: the fallback chain *looked* broken
(`fallbackConfigured:false`), which invites theories about same-provider de-dupe in the
fallback runner. It wasn't that — a session override disables configured fallbacks
outright. Check for overrides before theorising about the runner.

## Where the override lives

`~/.openclaw/agents/<agentId>/agent/openclaw-agent.sqlite` — a **different db** from
`~/.openclaw/state/openclaw.sqlite` (which holds `authProfiles.store`). Both places carry
model pinning; clear both.

| Table | Fields | Notes |
|---|---|---|
| `session_nodes` | `current_session_id`, `entry_json`, `status`, `entry_valid` | `entry_json` JSON may contain `modelOverride`, `providerOverride`, `modelOverrideSource` (`"user"` = pinned by an in-chat command), `modelOverrideRouteResolution`, `authProfileOverride` (e.g. `"kimi:default"`), `authProfileOverrideSource`, `authProfileOverrideCompactionCount`, `lastRunError` |
| `session_windows` | `model_provider`, `model`, `status` | per-window resolved model — can be read back even after the node is cleared |

Session keys look like `agent:<agentId>:<channel>:direct:<peer>` /
`agent:<agentId>:<channel>:group:<id>`; non-channel sessions (`agent:main:main`,
`agent:main:cron:*`, `agent:main:dashboard:*`) can carry overrides too.

Find every pinned session:

```bash
DB=~/.openclaw/agents/main/agent/openclaw-agent.sqlite
sqlite3 "$DB" "SELECT session_key, status FROM session_nodes WHERE entry_json LIKE '%modelOverride%';"
sqlite3 "$DB" "SELECT session_key, current_session_id, status FROM session_nodes WHERE session_key LIKE 'agent:main:qqbot:%';"
```

## Clearing it (keeps the transcript)

`cp` the db first: `cp openclaw-agent.sqlite openclaw-agent.sqlite.bak-$(date +%Y%m%d-%H%M%S)`.
Clearing the override fields preserves conversation history — prefer it to deleting the
`session_nodes` row (which drops the session link entirely).

```python
import json, sqlite3, time
db = sqlite3.connect("/home/sato/.openclaw/agents/main/agent/openclaw-agent.sqlite")

targets = [r[0] for r in db.execute(
    "SELECT session_key FROM session_nodes WHERE entry_json LIKE '%modelOverride%'")]

for sk in targets:
    entry_json, = db.execute(
        "SELECT entry_json FROM session_nodes WHERE session_key=?", (sk,)).fetchone()
    e = json.loads(entry_json)
    for k in ("modelOverride", "providerOverride", "modelOverrideSource",
              "modelOverrideRouteResolution", "authProfileOverride",
              "authProfileOverrideSource", "authProfileOverrideCompactionCount",
              "lastRunError"):
        e.pop(k, None)
    e["status"] = None
    e["updatedAt"] = int(time.time() * 1000)
    db.execute("UPDATE session_nodes SET entry_json=?, entry_valid=0, status=NULL, updated_at=? "
               "WHERE session_key=?",
               (json.dumps(e, ensure_ascii=False, separators=(',', ':')),
                int(time.time() * 1000), sk))
    sid, = db.execute("SELECT current_session_id FROM session_nodes WHERE session_key=?",
                      (sk,)).fetchone()
    db.execute("UPDATE session_windows SET model_provider=NULL, model=NULL, status=NULL "
               "WHERE session_id=?", (sid,))

db.commit()
```

Then verify by re-reading `entry_json` and asserting the keys are gone, and hand the user
`systemctl --user restart openclaw-gateway.service` (the self-restart guard blocks an
agent-issued restart — see the parent SKILL.md).

Notes:

- Keep the compact `separators=(',', ':')` serialization, same as the auth-store blob.
- The transcript, `usageFamilyKey`, `sessionId` and delivery route survive the clear; only
  the model pin is dropped, so the next message on that channel re-resolves from
  `agents.defaults.model`.
- The running gateway caches session state, so a restart is needed for the clear to take.
- Re-issuing whatever in-chat command pinned the model will pin it again. If the user wants
  a permanent model, change `agents.defaults.model`, not the per-session pin — and say so,
  because the pin is invisible from every config file.

## Verification status (be honest about this)

2026-09-19: the clear + `session_windows` cleanup was applied and verified by re-reading
the sqlite rows, but **end-to-end confirmation was not observed in-session** — the gateway
restart is user-issued, so no post-restart QQ reply was seen landing on `deepseek` (then
failing over to `minimax/MiniMax-M3`). Treat the recipe as the best available path and
confirm in the gateway log after the restart:

```bash
grep -E "agent model:|model-fetch start|model-fallback|fallbackConfigured" \
  /tmp/openclaw/openclaw-$(date +%F).log | tail -20
```

Also unverified: whether `entry_valid=0` / `status=NULL` are *required* for the rebuild, or
whether removing the override keys alone suffices. Removing the keys is the operative part.

`scripts/openclaw-model-routing-check.py` scans for these overrides — run it before
concluding that a routing-config edit did nothing.
