# Probing OpenClaw state from Hermes — tooling notes

Companion to `references/model-routing-and-auth-store.md`. Both pitfalls below were hit
for real while reading OpenClaw's config/sqlite/dist from Hermes `execute_code`.

## 1. `%`-formatting vs SQL `LIKE '%…'`

This looks harmless and explodes:

```python
db = "/home/sato/.openclaw/state/openclaw.sqlite"
terminal("sqlite3 %s \"SELECT state_key FROM config_machine_state WHERE state_key LIKE 'auth%';\"" % db)
# TypeError: not enough arguments for format string
```

The stray `%` in `LIKE 'auth%'` is parsed as a conversion specifier, so Python thinks the
format string has two placeholders.

Fixes, in order of preference:

```python
# a) avoid %-formatting entirely — concat with an already-quoted path
import shlex
db = shlex.quote("/home/sato/.openclaw/state/openclaw.sqlite")
terminal("sqlite3 " + db + " \"SELECT ... LIKE 'auth%';\"")
```

```python
# b) keep %-formatting but escape the literal percent
terminal("sqlite3 %s \"... LIKE 'auth%%';\"" % db)
```

```python
# c) f-string, with the path pre-quoted so no stray formatting chars leak in
q = shlex.quote(path)
terminal(f'sqlite3 {q} "... WHERE state_key LIKE \'auth%\';"')
```

Cleaner still: skip the shell for SQL. `sqlite3`-via-subprocess is unnecessary when you
are already in Python — use the stdlib directly, which sidesteps the whole quoting and
escaping class of bugs:

```python
import json, sqlite3
with sqlite3.connect("file:/home/sato/.openclaw/state/openclaw.sqlite?mode=ro", uri=True) as c:
    uv = c.execute("PRAGMA user_version").fetchone()[0]
    row = c.execute(
        "SELECT value_json FROM config_machine_state WHERE state_key='authProfiles.store'"
    ).fetchone()
    profiles = json.loads(row[0])["profiles"]
```

Use `mode=ro` so an inspection can never write to a DB the live gateway owns.

## 2. Do not print whole dist bundles

Grepping the built JS for a symbol returns minified lines that can be tens of KB each —
one grep of `projects/openclaw/dist` produced a 52 KB result. Always bound it:

```bash
grep -A3 'assertSupportedSchemaVersion' <dist file>
```

or filter in Python and print only the matched fragment. Otherwise the tool result is
mostly noise and buries the one line you actually wanted.

## 3. Which install is answering?

Two OpenClaw installs can coexist (npm global under nvm, and a git+pnpm checkout).
The one that matters is whichever the *running process* launched from — read the actual
cmdline rather than inferring from `which`:

```bash
ps -o pid,etime,cmd -C node | grep -i openclaw
readlink -f /home/sato/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw
```
