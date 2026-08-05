---
name: chat-stickers
description: "Send stickers/GIFs; view images without vision tools."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [chat, stickers, gif, media, qq, telegram, kaomoji]
---

# Chat Stickers & Media Delivery

Sending images/GIFs/stickers in chat conversations, and viewing images when no vision tool is available.

## When to use
- User asks "can you send stickers/表情包" or wants a GIF/meme in chat
- A chat moment where an image/GIF would serve as emotional punctuation
- User sends an image and no vision tool is available — view it via the ASCII fallback

## User preference (this user)
- 表情包/GIF are used **proactively as emotional expression** during chat — do NOT wait to be asked. When the mood fits (user is excited, sad, playful, or just sent media back), send one.
- Cute/cat content lands well; reply with a warm 萌系 tone alongside the media.
- Cache downloaded stickers under `~/.hermes/stickers/` for reuse.

## Sending media
Include `MEDIA:/absolute/path/to/file` in the reply (works on QQ, Telegram, etc.).
**Always validate before sending**: `file x.gif` + PIL check (format/size/n_frames) — never deliver an unvalidated download.

## No-key GIF sources (no API key needed)
- `https://cataas.com/cat/gif` — random cat GIF, zero setup. Append `?t=$(date +%s)` to bust cache.
- **Quirk**: curl often exits 28 (timeout) yet the file is complete — curl preserves downloaded bytes on timeout. Verify with `file`/PIL before discarding a "failed" download.
- If fetches hang, this machine needs an explicit proxy on some routes: `curl -x http://127.0.0.1:7890 ...` (no global proxy env is set).
- If `TENOR_API_KEY` is configured, prefer the `gif-search` skill for keyword search; this skill is the no-key fallback.

## Viewing images without vision tools (ASCII fallback)
Convert to grayscale, resize to ~70–80 columns (height × 0.5 to correct for character aspect ratio), map luminance to `' .:-=+*#%@'`. For GIFs, extract a frame first (`im.seek(n)`). Use `scripts/ascii_view.py <path> [frame] [width]`.
ASCII output is enough to identify subject, pose, and mood of most images (cat faces, portraits, memes).

## Pitfalls
- `terminal` may reject a `python3 -c '...'` invocation with a lifecycle-guard error ("embedded null byte") that looks like a syntax failure — it is not. Run the identical snippet via `execute_code` instead.
- Large GIFs (1.5MB+) deliver slowly on some platforms; prefer smaller sources when available.
- Keeping image-processing snippets in script files (see below) avoids the terminal guard issue entirely.

## Support files
- `scripts/ascii_view.py` — print any image or GIF frame as ASCII art
- `scripts/fetch_cat_gif.sh` — download + validate a random cat GIF into ~/.hermes/stickers/
