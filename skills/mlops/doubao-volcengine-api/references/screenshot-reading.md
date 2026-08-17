# Reading UI screenshots with Doubao VLM (direct curl)

Use when vision_analyze fails (e.g. 403 "model not available in your region"
from the aux vision provider) or when you need to read a live UI (billing
dashboards, charts, settings pages) from a screenshot.

## Pattern (Hyprland/Wayland host)
1. Focus the target window first: `hyprctl dispatch focuswindow class:^chromium$`
2. Capture: `grim /tmp/shot.png` (full screen). Take the grim screenshot via
   terminal — the execute_code sandbox may lack WAYLAND_DISPLAY and grim fails.
3. Downscale: `convert shot.png -resize 1600x -quality 82 shot.jpg`
   (or PIL thumbnail). Keep the image < ~200KB; b64 ~150KB is fine and fast.
4. POST to Ark (OpenAI-compatible chat/completions):
   - model: `doubao-seed-2-0-lite-260428`
   - content: image_url with `data:image/jpeg;base64,<b64>` + text prompt
   - curl `--max-time 150` (responses take 20-90s)
   - `max_tokens` ~1000-1500

## Reading detail
- Crop into quadrants/bands with PIL before sending — whole-page downscaling
  loses small digits and chart values.
- Prompt for verbatim digits ("请逐字读出所有数字") — structured prompts get
  structured answers; it reads charts/tooltips/stat cards reliably.
- Hover tooltips (e.g. per-day token breakdowns on usage charts) appear in
  screenshots if the pointer is over the element — ask the user to hover, then
  screenshot.
- Doubao is reliable on STRUCTURED UI content but hallucinates on memes/oral
  content (see skill's hallucination note) — for UI numbers, cross-check with a
  second crop if a value looks off.

## Script shape (python)
```python
import base64, json, subprocess
b64 = base64.b64encode(open('/tmp/shot.jpg','rb').read()).decode()
payload = {"model": "doubao-seed-2-0-lite-260428",
  "messages": [{"role": "user", "content": [
    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}},
    {"type": "text", "text": "读数字"}]}],
  "max_tokens": 1200}
open('/tmp/payload.json','w').write(json.dumps(payload))
r = subprocess.run(['curl','-s','--max-time','150',
  'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
  '-H','Content-Type: application/json',
  '-H','Authorization: Bearer <ark-key>',
  '-d','@/tmp/payload.json'], capture_output=True, text=True)
print(json.loads(r.stdout)['choices'][0]['message']['content'])
```
