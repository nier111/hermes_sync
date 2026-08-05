# NetEase Cloud Music / YesPlayMusic — concrete recipe

Verified 2026-08-05 on Arch Linux (pacman `yesplaymusic 0.4.10-1`, Electron app).

## Install & data layout

- Binary: `/opt/YesPlayMusic/yesplaymusic`; data: `~/.config/yesplaymusic/` (~2G: `blob_storage/` media cache, `Local Storage/leveldb/`, `IndexedDB/http_localhost_27232.indexeddb.leveldb/`, `Cookies` SQLite).
- The app serves its own web UI and bundles a NeteaseCloudMusicApi server (Express).

## Ports (when app is running)

- `127.0.0.1:27232` — web UI. Root returns 200 + HTML (`<title>OpenClaw...` no — YesPlayMusic SPA). Identified as UI because root returns HTML.
- `127.0.0.1:10754` — bundled API server. Root returns `Cannot GET /` (Express 404 HTML) — that's the tell it's an API server. `0.0.0.0:10754` in `ss -tlnp`.

## Local API endpoints that work (no auth, no cookies)

- `GET /login/status` → `{"data":{"code":200,"account":null,"profile":null}}` — server is STATELESS; the web app passes cookies per-request. account:null is normal, not a failure.
- `GET /playlist/track/all?id=<playlistId>&limit=1000&offset=0` → FULL track list including the liked playlist (红心), even unauthenticated. Paginate by offset until fewer than `limit` tracks returned. 2563-track liked list = 3 pages.
- `GET /playlist/detail?id=...` also available.

## Public music.163.com API (no login) — limited

- `https://music.163.com/api/user/playlist/?uid=<uid>&limit=30` — works unauthenticated; returns playlist names/counts including the liked playlist (`specialType=5` = 红心歌单).
- `https://music.163.com/api/v3/playlist/detail?id=<pid>` — TRUNCATES tracks to ~10–24 without auth. Do not rely on it for full data; use the local server instead.
- Headers that matter: `User-Agent` (browser UA), `Referer: https://music.163.com/`.

## Account data from localStorage (LevelDB, UTF-16LE)

- Key `user` holds a JSON blob with full profile: `userId`, `nickname`, `likedSongPlaylistID` (= red-heart playlist id), `loginMode`, `vipType`, `gender`, `province`/`city`. Extract with UTF-16LE byte search (see SKILL.md step 3).
- Example found: nickname 搞点饭吃吃捏, uid 1763420743, likedSongPlaylistID 2667995820.
- MUSIC_U / __csrf / NMTID were NOT recoverable from localStorage, IndexedDB, or the Cookies SQLite (Chromium-encrypted or kept in app memory). Don't chase them — the local API server makes them unnecessary.

## Analysis pattern that worked

- Merge pages → dedupe by `id` → `collections.Counter` over `ar[].name` for artist rankings → spot-check user-mentioned tracks by substring match on lowercased names.
- Subscribed (not created) playlists also fetchable in full via local server, e.g. 阴间音乐(胆小勿点) id 4970868678 (26 tracks) — useful when a user mentions a track that's not in their liked list (e.g. White Food lives there, not in 红心).

## Outputs kept for this user

- `/home/sato/persona/netEase-liked-songs-full.json` (2563 tracks: id/name/artists/album)
- `/home/sato/persona/netease-profile.md` (taste profile + top-20 artists + user self-description)
