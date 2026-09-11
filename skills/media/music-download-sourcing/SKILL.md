---
name: music-download-sourcing
description: "Use when sourcing downloadable high-quality music files."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
---

# Music file sourcing (legit hi-fi downloads & plugin players)

Covers: getting DRM-free, importable music files; evaluating plugin-based players like MusicFree; and proving a downloaded file is what it claims.

## Route ordering for legitimate downloadable audio

1. **Bandcamp** — FLAC/ALAC/WAV/AIFF, no DRM, re-downloadable. Best for indie/lo-fi/artist-direct.
2. **Qobuz Download Store** — buy DRM-free FLAC (CD + Hi-Res); region/payment gated. NOTE: search snippets can land on lookalike pages — verify the album/artist on the page before trusting a URL.
3. **OTOTOY / mora / RecoChoku** — Japanese/ACG/OST coverage, often FLAC/Hi-Res; region/JP-payment gated.
4. **7digital / HDtracks** — western catalogs.
5. **Apple/iTunes Store (JP etc.)** — buy = DRM-free m4a (256k AAC), not FLAC. Requires a store-account purchase.

Streaming "offline download" (Apple Music/TIDAL subscription, Spotify) is DRM — cannot be imported into a game or another player. Check whether a claimed "Hi-Res FLAC" is actually an upscale: CD-era releases are 16/44.1; a suspicious 24/192 rip of a CD-only album usually is.

## Anime OSTs are often enclosure-only

Many film/short OSTs ship only as a CD bundled inside a limited Blu-ray (e.g. Summer Ghost EYXA-13700/B, 2022-03-25, 29 tracks/~33 min: 小瀬村晶/当真伊都子/Guiano/HIDEYA KOJIMA). Verify via VGMdb + the official site (summerghost.jp/bd/), buy the set, rip the CD to FLAC, then transcode for use.

## Format guidance when importing into a game/player

- Keep tracks as separate files; do not concatenate an album into one long file (Unity games can stall/decode-hang GPU on ~1 h MP3 imports; community reports on Chill with You).
- MP3 320k CBR/V0 44.1 kHz stereo is the safest import target; transcode from FLAC with `ffmpeg -i in.flac -c:a libmp3lame -b:a 320k -map_metadata 0 out.mp3`.
- Never "upconvert" lossy → FLAC; bigger file, no quality back.

## MusicFree desktop plugin ecosystem (verified 2026-09)

- Official desktop project: maotoumao/MusicFreeDesktop; Linux ships only a `.deb` (0.0.8). Avoid the AUR `musicfree-desktop` (depends on retired electron25); extract the official .deb under `~/.local/opt` instead.
- Old bundled Electron crashes its GPU process on NVIDIA/Wayland (`GPU process isn't usable`); launch with `--no-sandbox --disable-gpu --ozone-platform=x11`. Music player = no GPU needed.
- Desktop plugins share the mobile protocol; scanned from `~/.config/MusicFree/musicfree-plugins` on startup. Search UI is usable over Electron CDP (`--remote-debugging-port`).
- Official sample-plugin repo removed CN platform sources after a takedown notice; remaining samples (FreeSound etc.) may implement search/play only — a click on 下载 can leave the download queue empty. Third-party "all-platform/VIP" plugins execute arbitrary JS; audit code before installing.
- A working no-DRM download test path: FreeSound public search HTML (`freesound.org/search/?q=`) exposes `data-sound-id/data-title/data-mp3` attributes; MP3 preview CDNs (`cdn.freesound.org/previews/...`) download directly. Verify with ffprobe after download.

## Driving an Electron app for UI tests without extra packages

Node ≥ 22 has a native WebSocket; no `websocket`/`playwright` module needed to drive an Electron app's renderer over CDP: launch the app with `--remote-debugging-port=NNNN`, read `http://127.0.0.1:NNNN/json/list`, then Runtime.evaluate to read DOM, find elements by text, click via `Input.dispatchMouseEvent` at `getBoundingClientRect()` center, and poll for results. React state changes usually need real input events or real mouse clicks, not bare `element.click()`.
