# Injecting a provider key into the auth store by hand

Companion to `references/model-routing-and-auth-store.md` (which maps where the pieces
live and how to edit `openclaw.json`). This file covers the **credential** half:
how to write a key in when the CLI is schema-deadlocked, and how to prove it works.

## Where the key lives

`~/.openclaw/state/openclaw.sqlite` → table `config_machine_state`,
`state_key='authProfiles.store'`, JSON blob:

```json
{"version":1,"profiles":{
  "minimax:default":{"type":"api_key","provider":"minimax","key":"sk-cp-…"},
  "deepseek:default":{"type":"api_key","provider":"deepseek","key":"sk-…"}}}
```

Profiles are keyed `<provider>:default`. `~/.openclaw/credentials/` holds only
`browser-extension-relay.secret` on this box — the provider keys are in sqlite.

## Writing it (CLI unusable path)

Back up first: `cp openclaw.sqlite openclaw.sqlite.bak-$(date +%Y%m%d-%H%M%S)`.

```python
import json, sqlite3, time
db = sqlite3.connect("/home/sato/.openclaw/state/openclaw.sqlite")
row = db.execute("SELECT value_json FROM config_machine_state "
                 "WHERE state_key='authProfiles.store'").fetchone()
data = json.loads(row[0])
data["profiles"]["minimax:default"]["key"] = NEW_KEY
db.execute("UPDATE config_machine_state SET value_json=?, updated_at_ms=? "
           "WHERE state_key='authProfiles.store'",
           (json.dumps(data, ensure_ascii=False, separators=(',', ':')),
            int(time.time() * 1000)))
db.commit()
```

- Keep the **compact** `separators=(',', ':')` serialization — the gateway wrote the blob
  compact and hashes its shape; pretty-printing changes the hash for nothing.
- The row has `updated_at_ms`; stamp it.
- The gateway caches the auth store at startup → **a restart is required** before the key
  is used. And `systemctl --user restart openclaw-gateway.service` must be issued by the
  user (self-restart guard; see the parent SKILL.md).
- Re-read the row afterwards and assert the value equals what you wrote. Editing the blob
  is not proof either — probe the key itself (next section).

## A key can be the right length and still be dead

Verified 2026-09-19: `minimax:default` held a **125-byte `sk-cp-…` key that 401'd on every
MiniMax endpoint**, including ones that make no model call:

```
HTTP 401 {"type":"error","error":{"type":"authorized_error","message":"login fail:
Please carry the API secret key in the 'Authorization' field of the request header (1004)"}}
```

A revoked subscription key and a good one are indistinguishable in a dump — same prefix,
same length. Probe with a real round-trip:

```bash
python3 ~/.hermes/skills/mlops/api-cost-forensics/scripts/probe-subscription-key.py \
  --file ~/.openclaw/state/openclaw.sqlite --sqlite-key minimax:default
```

(That script is owned by `api-cost-forensics`; see
`references/subscription-key-validity.md` there for the redaction-artifact failure mode —
a 13-byte `sk-cp-...atGk` placeholder pasted out of chat output, same head and tail as
the real key.)

## Cross-check after a restart

`scripts/openclaw-model-routing-check.py` prints routing + auth-store entries + a gateway
probe. Run it, then confirm the key values it reports are the ones you wrote, and then
exercise a real message before calling the chain live.
