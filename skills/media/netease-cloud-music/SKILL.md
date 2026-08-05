---
name: netease-cloud-music
description: "Use when reading NetEase user data (playlists, liked songs)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
---

# NetEase Cloud Music — Read User Data

User's account: 搞点饭吃吃捏 (uid 1763420743; liked-playlist id 2667995820, 2563 liked songs). Saved artifacts: `~/persona/netease-profile.md`, `~/persona/netEase-liked-songs-full.json`.

## Path A — YesPlayMusic local API server (BEST: full data, no auth)
While YesPlayMusic runs (AUR pkg `yesplaymusic`, config `~/.config/yesplaymusic`):
- Web UI server: `127.0.0.1:27232`. Bundled NeteaseCloudMusicApi server: `127.0.0.1:10754`.
- Full playlist (incl. liked list): `GET http://127.0.0.1:10754/playlist/track/all?id=<playlistId>&limit=1000&offset=N`
  Returns the FULL track list WITHOUT login — paginate offset 0/1000/2000 (2563 songs → 3 pages, ~2MB/page). Dedup by track id.
- `GET http://127.0.0.1:10754/login/status` → account:null (stateless; cookies live in the web app, not the API server).
- Finding the port: `ss -tlnp | grep yesplaymusic` — the API port is the one that 404s on `/` ("Cannot GET /") but answers API paths.

## Path B — public API without login (works with app closed)
- Playlist list: `https://music.163.com/api/user/playlist/?uid=<uid>&limit=30` with headers `User-Agent` + `Referer: https://music.163.com/`. Returns names, trackCount, playCount; `specialType=5` marks the liked playlist.
- Track lists are TRUNCATED without auth (~10-24 tracks) — enough for a taste sample, NOT for the full liked list.

## Path C — Electron local data (~/.config/yesplaymusic)
- `Local Storage/leveldb/` — Chromium localStorage; VALUES ARE UTF-16LE (search keys AND values UTF-16-encoded). Contains user profile JSON: userId, nickname, avatarUrl, `likedSongPlaylistID`, loginMode, lastLoginIP.
- `Cookies` (Chromium sqlite) — only placeholder localhost cookies; MUSIC_U is NOT persisted here or in localStorage (login lives in the running app). Don't burn time hunting the cookie — use Path A.
- `IndexedDB/http_localhost_27232.*` — app caches; low value.

## Pitfalls
- sqlite3 query redirect-to-file returning 0 bytes + exit 0 while direct run shows rows → tmpfs full (Errno 122); check `df -h /tmp`, write to home dir.
- Reading Hermes `state.db` while the gateway runs → WAL lock contention; use `PRAGMA busy_timeout=5000`.
- `read_file` flags Chinese/emoji md as binary → read via `cat`.
- NetEase blocks bare requests: always send a browser UA + Referer.

## Scripts
- `scripts/fetch_liked_songs.py` — paginated full pull from the local API server + dedup + save (run while YesPlayMusic is open).
