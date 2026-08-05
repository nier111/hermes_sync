# Extracting messages that arrived on another platform/session

Scenario: the user says "I just sent you X on QQ/Telegram/..." but the current
session (e.g. CLI) never received it. The gateway delivers per-platform
sessions, so the message lives in THAT platform's session, not yours.

## Locate the session

- `~/.hermes/sessions/sessions.json` — gateway routing index mapping
  `agent:main:<platform>:...` session keys to `session_id`s (e.g.
  `agent:main:qqbot:dm:<userid>`). Note: this file is a LEGACY MIRROR; the
  canonical copy is the `gateway_routing` table in `~/.hermes/state.db`.
- `~/.hermes/state.db` tables: `sessions`, `messages` (session_id, role,
  content, ...), `messages_fts` (full-text search).

## Extract

```python
import sqlite3
conn = sqlite3.connect('/home/<user>/.hermes/state.db')
conn.execute("PRAGMA busy_timeout=5000")          # gateway is actively writing
rows = conn.execute(
  "SELECT id, content FROM messages WHERE session_id=? AND role='user' ORDER BY id",
  (SESSION_ID,)).fetchall()
```

- Long content arrives split across many sequential messages (platform length
  limits) — reassemble by joining parts in id order.
- Prefer the `python3 - <<EOF` heredoc form over the `sqlite3` CLI: the CLI's
  stdout redirect can silently produce an empty file while still exiting 0
  (seen against a live WAL database). Python with `busy_timeout` is reliable.

## Cleaning the extracted text

- QQ-origin content can contain NUL bytes (`\x00`) — strip with
  `data.replace(b'\x00', b'')` before treating it as text.
- Do NOT use `grep -c $'\x00'` to count NULs — grep cannot take NUL patterns
  and returns bogus line counts. Use `python3 -c "...count(b'\x00')"`.
- `read_file` may refuse CJK/emoji-heavy files as "Binary file" (heuristic
  false positive on high non-ASCII ratio). Read them with terminal `cat`
  instead; the file is valid UTF-8.
- Check `df -h /tmp` before writing extracted data to /tmp — tmpfs fills fast
  (e.g. a 2.5G OpenClaw update preflight); write to home instead.
