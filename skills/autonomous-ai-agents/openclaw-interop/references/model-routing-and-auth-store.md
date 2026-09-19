# OpenClaw model routing, fallbacks, and the auth profile store

Verified 2026-09-19 by reading the running gateway's own dist bundle + the repo source,
and by editing `~/.openclaw/openclaw.json` directly. Read this before changing
provider/model/fallback config on any machine.

## Where the pieces live

| What | Where |
|---|---|
| Model routing / primary + fallbacks | `~/.openclaw/openclaw.json` → `agents.defaults.model` |
| Per-agent override | `agents.<id>.model` (same shape) |
| Alias + allowlist of model refs | `agents.defaults.models` (map) + `agents.defaults.modelPolicy.allow` (array) |
| Provider plugins | `plugins.entries.<pluginId>` (`.enabled`, `.config`) |
| Ad-hoc provider endpoints | `models.providers.<id>` (baseUrl/model/api key shape) |
| **API keys / OAuth profiles** | `~/.openclaw/state/openclaw.sqlite` → table `config_machine_state`, `state_key='authProfiles.store'` (JSON blob) and `authProfiles.state` |

`agents.defaults.model` shape:

```json
{
  "primary": "deepseek/deepseek-v4-flash",
  "fallbacks": ["minimax/MiniMax-M3", "deepseek/deepseek-v4-flash"]
}
```

`fallbacks` is an ordered list of `"<provider>/<model>"` strings. The field name IS
`fallbacks` (plural) — older notes referring to `fallback` are wrong.

The auth store JSON blob looks like:

```json
{"version":1,"profiles":{
  "deepseek:default":{"type":"api_key","provider":"deepseek","key":"sk-..."},
  "minimax:default" :{"type":"api_key","provider":"minimax","key":"sk-cp-..."},
  "openai:default"  :{"type":"oauth","provider":"openai","access":"eyJ..."}}}
```

Read it with (mind the `%%` escaping pitfall below):

```bash
sqlite3 ~/.openclaw/state/openclaw.sqlite \
  "SELECT json_extract(value_json,'$.profiles.\"minimax:default\".key') FROM config_machine_state WHERE state_key='authProfiles.store';"
```

Keys are in this sqlite blob, NOT in `~/.openclaw/credentials/` (that dir only holds
`browser-extension-relay.secret` on this box).

## Bundled provider plugins carry their own defaults

`projects/openclaw/extensions/<provider>/` (e.g. `extensions/minimax/provider-models.ts`)
declares the default `baseUrl` and model list. Verified for `minimax` (MiniMaxAI, not the
MiniMaxi abab vendor):

- `baseUrl: https://api.minimax.io/anthropic` (Anthropic-messages transport)
- models: `MiniMax-M3` (default), `M2.7`, `M2.7-highspeed`
- key accepted: `sk-api-…` or `sk-cp-…` (the `sk-cp-` subscription/Token-Plan keys work)

**Do not leave a duplicate `models.providers.<sameId>` stanza in place.** In this session
`models.providers.minimax` held a *different* vendor's endpoint
(`https://api.minimaxi.chat/v1` + `abab6.5s-chat`). Removing that stanza so the plugin
default applies was the fix; the stale `agents.defaults.models["minimax/abab6.5s-chat"]`
alias entry is harmless but pointless.

Checklist to add a provider/model to the fallback chain by hand:

1. `plugins.entries.<pluginId>.enabled = true`
2. `agents.defaults.models["<provider>/<model>"] = {"alias": "<Name>"}`
3. `agents.defaults.modelPolicy.allow += ["<provider>/<model>"]`
4. `agents.defaults.model.fallbacks = [...]` (ordered)
5. delete any conflicting `models.providers.<sameId>` stanza
6. confirm `<provider>:default` exists in the sqlite auth store (step the CLI would do)
7. user restarts the gateway (see below), then verify

## When the CLI cannot be used at all

Symptom: every openclaw CLI invocation dies reading state, because the pnpm/repo build
asserts a max supported sqlite `PRAGMA user_version` (grep the dist bundle for
`assertSupportedSchemaVersion` — this build capped at 6) while the **running gateway** was
installed from npm at a newer version and migrated the DB (here `user_version = 15`).

Two different installs are in play on this box:
- gateway = `~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw` (npm global, v2026.8.1, systemd unit)
- CLI     = `~/projects/openclaw` (git repo + pnpm, different version, different schema cap)

So: `pnpm openclaw config set ...` / `auth add ...` / `plugins enable ...` are all
unavailable while the drift exists. The working path is **edit `openclaw.json` +
sqlite by hand, then restart the gateway**. `systemctl --user restart
openclaw-gateway.service` must be issued by the USER — an agent-initiated restart is
blocked by the self-restart guard.

This is version drift, not a permanent property: after a matching `pnpm openclaw update`
or an npm bump of one side, re-check `PRAGMA user_version` vs the dist cap before
concluding the CLI is unusable.

## Verification (config edits are not proof)

`scripts/openclaw-model-routing-check.py` prints the routing fields, the auth store
entries, and probes the local gateway. Run it after the restart.

Two behaviours are **still unverified** and must be tested with a real message, not assumed:

- Whether the fallback runner skips a fallback entry whose provider equals the failed
  primary (some runners de-dupe by provider to avoid re-burning a dead endpoint). If it
  does skip, a chain of `primary=deepseek/X, fallbacks=[minimax/Y, deepseek/Z]` loses its
  last-resort hop and needs a third provider.
- Whether a gateway restart / auto-update preserves the hand-edited `openclaw.json`
  (there is a prior incident of update flow clobbering config). Always `cp
  openclaw.json openclaw.json.bak-$(date +%Y%m%d-%H%M%S)` first and diff after restart.
