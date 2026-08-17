# Reading image-only PDFs / manuals with Doubao VLM

Verified workflow (2026-08) on a 1-page Chinese audio-device manual (水月雨水解2Ti 说明书).
PDF had no text layer: `pdftotext` returned 1 byte. `pdftoppm -png -r 200` produced a 1.3MB PNG — too big for a single API call; 150dpi JPEG was the sweet spot.

## Steps

```bash
pdftoppm -jpeg -r 150 /path/file.pdf /tmp/page     # → /tmp/page-1.jpg ≈ 350 KB
```

Python request (direct connection — Volcano Ark is domestic; do NOT pass the 7890 proxy env):

```python
import base64, json, urllib.request

b64 = base64.b64encode(open("/tmp/page-1.jpg", "rb").read()).decode()
payload = {
    "model": "doubao-seed-2-0-lite-260428",
    "max_tokens": 4000,
    "messages": [{
        "role": "user",
        "content": [
            {"type": "text", "text": "请把这张说明书图片里的所有中文文字逐字、完整地转录出来,包括标题、正文、小字、脚注,一个都不要漏。按阅读顺序输出。不要总结、不要省略。"},
            {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}}
        ]
    }]
}
req = urllib.request.Request(
    "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json", "Authorization": "Bearer <ark-key>"},
    method="POST",
)
# urlopen with timeout=170; ~50-60s per page on lite
```

## Prompt strategy — transcribe FIRST, extract LATER

- BAD: "提取说明书中关于指示灯的所有内容" → model pre-filters, silently drops
  sections it deems irrelevant. First attempt only returned the LED colors
  (PCM=red / DSD=blue) and nothing else.
- GOOD: "逐字完整转录,不要总结、不要省略" → returned the entire manual
  (操作指南/连接方法/功能操作/参数规格/售后条款/保修卡), which is where the
  context that the questioner actually needed lived.

For answer-extraction tasks, do your own keyword pass over the verbatim
transcript instead of asking the model to do it in one shot.

## Pitfalls

- OCR typos happen: "PCM" came back as "CFM". Cross-check against context
  (CFM makes no sense as an audio format; PCM/DSD pairing does).
- vision_analyze may 403 in this region ("model not available in your region") —
  Doubao VLM via direct curl is the reliable fallback for image reading.
- Single dense A4 page at 150dpi is fine for one call; multi-page manuals:
  render each page separately, batch 1-2 pages per request, keep total under
  the 5-minute execution cap.
- If the answer hinges on a color/state mapping that the manual does NOT
  define (e.g. a LED color the manual omits), say so plainly and give the user
  a hands-on verification path (flip the setting in the vendor app / observe
  the device) instead of inventing the mapping.
