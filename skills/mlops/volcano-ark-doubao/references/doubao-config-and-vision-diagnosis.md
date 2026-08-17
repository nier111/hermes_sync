# Doubao config read + vision diagnosis (verified 2026-08)

Session-tested patterns. The user's key correction: read the SAVED config, never grep
the filesystem for `ark-` keys, and prefer Doubao VLM over local ollama for image work
(2GB-VRAM box is CPU-only and times out).

## Reading the config (block-scoped, not first-match)

Credentials live in `~/.hermes/config.yaml` under `model.aliases.doubao`. A naive
`base_url:\s*(https?://...)` regex grabs the FIRST base_url in the file (deepseek's),
which is wrong. Scope to the doubao block:

```python
import re
cfg = open('/home/sato/.hermes/config.yaml').read()
m = re.search(r'(?m)^\s*doubao:\s*\n((?:\s{4,}[^\n]+\n?)+)', cfg)
block = m.group(1)
base_url = re.search(r'base_url:\s*(\S+)', block).group(1)
api_key  = re.search(r'api_key:\s*(\S+)', block).group(1)
model    = re.search(r'model:\s*(\S+)', block).group(1)
```

## Calling the VLM (OpenAI-compatible)

POST `{base_url}/chat/completions`, `Authorization: Bearer {api_key}`,
model `doubao-seed-2-0-lite-260428`, messages with text + `image_url`
(`data:image/jpeg;base64,...`). Timeout ≥180s (lite ~50-95s/image).

## Vision diagnosis of GUI font rendering (worked example)

QQ Linux (Electron) Chinese text looked "虚/重影". Diagnosis path:
1. `grim /tmp/s.png` (Wayland fullscreen screenshot; `import -window root` fails on
   Wayland, `spectacle` may also fail — grim works on wlroots compositors).
2. PIL thumbnail to ≤1280px, save JPEG q80.
3. Feed to Doubao VLM: "QQ窗口文字是否清晰?对比终端/状态栏?" It returned a precise
   verdict: QQ text blurry/foggy (Electron ignoring fontconfig hinting/LCD config),
   system text crisp — and named the root cause.
4. Fix applied: user-level `~/.local/share/applications/qq.desktop` with
   `--disable-lcd-text --font-render-hinting=none --ozone-platform-hint=auto`
   (drun launchers read user-level .desktop with priority; clear rofi/wofi caches:
   `rm -f ~/.cache/rofi3.druncache ~/.cache/wofi-drun`). Verified working.

Local `qwen2.5vl:3b` via ollama on this box: CPU-only, >5min/image, timed out twice
even on small screenshots — do not default to it when Doubao is available.
