---
name: local-app-data-forensics
description: "Extract user data from locally installed apps."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [forensics, electron, leveldb, sqlite, local-api, data-extraction, netease, yesplaymusic]
---

# Local App Data Forensics

Extract user data out of locally installed apps: playlists, chat history, settings, account info. Works for any Electron/Chromium-based app (music players, chat clients, game launchers) and any app that ships a local API server.

## When to use

- User asks "can you access my <app> data" (网易云/YesPlayMusic, Discord, QQ, Spotify, etc.)
- Need account-scoped data (liked lists, friends, history) without asking the user to export anything
- App stores data locally and user is logged in on this machine

## Workflow

1. **Locate install + data dirs**: `pacman -Q <app>` / `command -v <app>`, then `~/.config/<app>`, `~/.local/share/<app>`. Check if the app is running (`ps aux | grep -i <app>`) — a running app is a huge advantage (fresh login state + live API server).

2. **Inventory storage**: Electron apps keep `Local Storage/leveldb/` (localStorage), `Cookies` (SQLite), `IndexedDB/`, `blob_storage/`. `du -sh` each to see where the weight is (large = cached media/playlists).

3. **LevelDB localStorage — UTF-16 gotcha (critical)**: Chromium stores localStorage keys AND values as **UTF-16LE**. Plain `strings`/`grep` on the .ldb/.log files finds almost nothing. Use:
   - `strings -e l *.ldb *.log` for readable key/value dumps, or
   - Python: search for `key.encode('utf-16-le')` byte patterns, decode surrounding bytes as utf-16-le. User profile JSONs (nickname, userId, app-specific IDs) usually live here in plaintext.
   - Alternatively use a real LevelDB reader (plyvel / `level` npm package) for exact key→value.

4. **Chromium Cookies SQLite**: `sqlite3 <app>/Cookies "SELECT host_key,name,length(encrypted_value) FROM cookies"`. Values are encrypted (Chromium Safe Storage) — often useless directly; also many apps keep dev-server cookies with 0-length values. Don't burn time here; localStorage or a local API server is the better path.

5. **The big win — running app = local API server**: `ss -tlnp | grep -i <app>` to find listening ports. Probe each: root returning HTML (`<title>` / 200 with content) = web UI; `Cannot GET /` (Express error) = API server. Apps bundling API servers (YesPlayMusic bundles NeteaseCloudMusicApi; many "web-shell" apps do the same) expose the FULL backend API locally — often **without auth**, even where the public API truncates unauthenticated responses. Probe known endpoints (`/login/status`, `/playlist/track/all`, etc.) and paginate with `limit/offset`.

6. **App not running?** Ask the user to launch it once (refreshes login state into localStorage) — then repeat steps 3–5. Reading localStorage of a running/just-run app beats cookie extraction every time.

7. **Save + verify**: write extracted data to the home dir, dedupe by id, spot-check known items (songs the user mentioned, expected counts). Report counts, not raw dumps.

## Pitfalls

- **`/tmp` is often a small tmpfs** (e.g. 3.8G, easily filled by update preflight/playwright downloads) → `OSError: Disk quota exceeded`. Check `df -h /tmp`; write extraction output to the home directory instead.
- **read_file refuses CJK/emoji-heavy text** (binary heuristic) → fall back to `cat` via terminal.
- **SQLite WAL lock contention** when the app/gateway is actively writing → `PRAGMA busy_timeout=5000` or retry; transient empty results are lock artifacts, not missing data.
- **NUL bytes in DB-extracted text** (LevelDB internals, message stores) → strip `b'\x00'` before saving; verify byte count changed to confirm NULs were real (grep -c on NUL patterns lies — it counts lines, and GNU grep mishandles NUL patterns).
- **Public APIs truncate without auth** (NetEase: ~10–24 tracks); the bundled local server often does NOT. Prefer the local server.
- Don't print session tokens/cookies into chat — use them via API calls, mask in output.

## Verification

- bash -n / syntax check any scripts before trusting them
- For paginated fetches: sum page sizes, dedupe by id, compare against the app-reported total
- Confirm extraction landed: file exists, byte count, spot-check first/last items

## References

- `references/netease-yesplaymusic.md` — concrete NetEase Cloud Music / YesPlayMusic endpoints, ports, and account data layout
- `scripts/fetch_netease_playlist.py` — paginate a full playlist via the local YesPlayMusic API server
