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
- **聊天表情包要 meme 梗图，不要猫猫 GIF** — user explicitly rejected generic cat GIFs ("太无聊了，不像聊天时候用的"). Wants internet memes like cheems (柴犬), 奶龙 (贱萌黄龙), 流汗黄豆, 蚌埠住了, etc. Reply with a warm 萌系 tone alongside the media.
- Cute/cat content is still fine as a *gift/pet* topic, but NOT as chat stickers.
- Cache downloaded stickers under `~/.hermes/stickers/` for reuse.

## Sending media
Include `MEDIA:/absolute/path/to/file` in the reply (works on QQ, Telegram, etc.).
**Always validate before sending**: `file x.gif` + PIL check (format/size/n_frames) — never deliver an unvalidated download.

## Meme 梗图来源（中文互联网，无 key 优先）
- `scripts/fetch_meme.sh <关键词> [输出路径]` — 从「发表情」站 (fabiaoqing.com) 搜中文梗图/表情包，优先 gif 否则 jpg。
  - 搜索路径必须是 `/search/bqb/keyword/<URL编码词>`（不是 `?keyword=`，那个返回首页推荐，所有词结果一样）。
  - 图片在懒加载属性 `data-original`，CDN 是 img.soutula.com，`/bmiddle/` 换 `/large/` 拿原图。
  - 下载需带 `Referer: https://www.fabiaoqing.com/`。
  - 梗图多为静态 jpg，不必强求 gif。
  - 热门词示例：奶龙、cheems、小狗cheems（这个站可能没有）、流汗黄豆、蚌埠住了、好好好、啊这、小丑、干饭人。
- **奶蛙 (Milky Frog)**：奶龙二创衍生梗（"大笑奶龙/变异奶龙"系），2026 年新火，黄色圆滚滚蛙、绿眼、张嘴狂笑，微信常见。fabiaoqing 尚未收录"奶蛙"——**官网直取** `https://milkyfrog.com/`：
  - pose 图：`assets/mf-pose-belly.png`(捧腹)、`mf-pose-rolling.png`(打滚)、`mf-pose-wave.png`(挥手)、`mf-pose-lying.png`(躺)、`milkyfrog-hero.png`(主视觉)、`mf-logo.png`
  - 动图：`assets/mf-stream-7b3f29d1c8.mp4`（需 ffmpeg 转 gif：`fps=10,scale=480:-1`）
  - 已缓存 `~/.hermes/stickers/milkyfrog/` 可直接复用
  - 官方还有 iOS/安卓表情包 app（App Store id6761310915 / 应用宝 com.lgzkmbg.nwbq）
- Tenor 网页搜索 (`tenor.com/search/<词>-gifs`) 无 key 也能通，但要 grep `.gif` 结尾（`AAAAM` 后缀）才是真 gif，`AAAPo` 是 mp4。老版 `g.tenor.com/v1` 接口已停用。

## No-key GIF sources (no API key needed)
- `https://cataas.com/cat/gif` — random cat GIF, zero setup. Append `?t=$(date +%s)` to bust cache. **只作备用**：user prefers meme 梗图 over cat GIFs.
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
- `scripts/fetch_cat_gif.sh` — download + validate a random cat GIF into ~/.hermes/stickers/ (备用)
- `scripts/fetch_meme.sh` — **首选**：fabiaoqing 中文梗图搜索下载（cheems/奶龙/流汗黄豆等）
