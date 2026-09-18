# Enabling a memory provider on a Hermes profile (Holographic, verified 2026-09-19)

Scope: per-profile `memory.provider` plus `plugins.hermes-memory-store`, giving a bot a
local, searchable fact store on top of the built-in `memories/USER.md` + `MEMORY.md`.
Verified end-to-end on the `gf` profile (Kubo) on this host.

## Commands

```bash
HERMES_HOME=/home/sato/.hermes/profiles/gf /home/sato/.local/bin/hermes config set memory.provider holographic
HERMES_HOME=/home/sato/.hermes/profiles/gf /home/sato/.local/bin/hermes config set plugins.hermes-memory-store.db_path /home/sato/.hermes/profiles/gf/memory_store.db
HERMES_HOME=/home/sato/.hermes/profiles/gf /home/sato/.local/bin/hermes config set plugins.hermes-memory-store.auto_extract true
HERMES_HOME=/home/sato/.hermes/profiles/gf /home/sato/.local/bin/hermes config set plugins.hermes-memory-store.default_trust 0.65
HERMES_HOME=/home/sato/.hermes/profiles/gf /home/sato/.local/bin/hermes memory status
```

`memory status` should print `Provider: holographic` and `holographic (local) ← active`.

## Pitfall 1 — `$HERMES_HOME` expands in the OUTER shell

```bash
HERMES_HOME=/x hermes config set ...db_path "$HERMES_HOME/memory_store.db"   # WRONG
```

The shell substitutes the variable before `hermes` runs, so the **default profile's** path
(`/home/sato/.hermes/memory_store.db`) gets written into the target profile's `config.yaml`.
Seen 2026-09-19 on the gf profile. Two consequences:

- Pass a literal absolute path; confirm with `hermes config get plugins.hermes-memory-store.db_path`.
- `hermes memory status` does **not** validate `db_path` — it happily reports "available ✓ / active"
  for a wrong path. Only a real write + search proves the wiring.

## Pitfall 2 — provider config is read at boot

A running gateway keeps the old provider until a real process restart (see the gateway-restart
reference in `hermes-qqbot-multi-profile`). Enabling a provider, adding the skill that uses it,
and changing memory caps all take effect on the **same single restart** — do them together, then
tell the user that one restart is still pending rather than claiming it is already live.

## Verification self-test (real DB, not a smoke test)

Instantiate the provider in-process against the profile's real config, exercise it, then delete
the probe fact:

```bash
HERMES_HOME=/home/sato/.hermes/profiles/gf PYTHONPATH=/home/sato/.hermes/hermes-agent \
  /home/sato/.hermes/hermes-agent/venv/bin/python selftest.py
```

```python
from hermes_cli.config import load_config_readonly, cfg_get
from plugins.memory.holographic import HolographicMemoryProvider

config = cfg_get(load_config_readonly(), 'plugins', 'hermes-memory-store', default={}) or {}
provider = HolographicMemoryProvider(config=config)
provider.initialize('selftest')
for action, args in (('add', {...}), ('search', {...}), ('probe', {...}), ('remove', {...})):
    provider.handle_tool_call('fact_store', {'action': action, **args})
provider.shutdown()
```

Then assert with `sqlite3`: `select count(*) from facts` back to 0 and `pragma integrity_check` = ok.
Expected tables: `facts`, `entities`, `fact_entities`, `facts_fts` (+`_data/_idx/_docsize/_config`),
`memory_banks`, `sqlite_sequence`.

## Chinese content: what actually works

- FTS5's default tokenizer indexes CJK well enough for substring-style recall — queries like
  `菲伦娃娃`, `边界感`, `爱情观` all returned the right facts.
- Entity extraction only catches: double/single-quoted spans (`"N"`, `"菲伦娃娃"`), capitalized
  Latin bigrams (`Summer Ghost`), and `X aka Y`. So **quote Chinese names and objects when writing
  facts** — that is what makes `fact_store action=probe entity=...` usable for "everything about X".
- Put the Chinese keywords in `tags` too; `search` sanitizes to OR-joined tokens across content + tags.
- `auto_extract` patterns in this plugin are **English-only** (`I prefer…`, `we decided…`,
  `the project uses…`). A Chinese-language companion bot gets *nothing* extracted automatically.
  Say that plainly to the user instead of implying auto-memory works in Chinese; the persona skill
  has to call `fact_store` explicitly on important turns.

## Seeding a store from the built-in memory files

`memories/USER.md` entries are separated by `\n§\n`. Splitting on that and inserting each entry as one
fact (`category=user_pref`, tags from a keyword whitelist) imports the existing profile in one pass.
It is idempotent — `facts.content` is UNIQUE, so a re-run returns the existing `fact_id` instead of
duplicating. Import entries **verbatim**; do not paraphrase the built-in file, it stays the canonical
skeleton. Verify with `count(*) == len(entries)` plus 3–4 search probes.

## Reporting shape that worked

State the layering explicitly and separate what is live from what is pending:

```text
SOUL.md            → who the bot is
<persona skill>    → how it should remember
USER.md / MEMORY.md→ always-injected skeleton
memory_store.db    → searchable event detail
state.db           → raw transcript evidence
```

Do not present "four layers of memory" as done while the restart is still owed.
