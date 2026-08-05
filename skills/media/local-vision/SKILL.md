---
name: local-vision
description: "Use when user sends images for recognition via local ollama."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
prerequisites:
  commands: [ollama, curl, python3]
metadata:
  hermes:
    tags: [vision, image, ocr, ollama, qwen2.5vl]
---

# Local Vision (ollama qwen2.5vl)

用本机 ollama 跑视觉模型识别图片内容。无需任何云 API key,纯本地,适合识别表情包、照片、截图、扫描 PDF 页面。

## When to use

- 用户发来图片且需要知道"这是什么/上面写了什么"
- 表情包/梗图识别(如"这是不是奶蛙?")
- 中文 OCR(扫描件、截图文字提取)
- 图片内容摘要

## 模型

- `qwen2.5vl:3b` — 默认,约 2.5GB,8核CPU+内存<8G的机器上也能跑
- 内存 ≥ 16G 可换 `qwen2.5vl:7b`(中文更强、更慢)

## 步骤

1. **确认模型已下载**:
```bash
ollama list | grep qwen2.5vl || HTTPS_PROXY=http://127.0.0.1:7890 ollama pull qwen2.5vl:3b
```
(国内网络 pull 必须带代理;下载要几分钟,用后台任务+notify)

2. **压缩图片**(控制速度;GIF 取第一帧):
```python
from PIL import Image
im = Image.open(path)
if getattr(im, 'n_frames', 1) > 1:
    im.seek(0)  # GIF 取首帧
im = im.convert('RGB')
if max(im.size) > 1280:
    im.thumbnail((1280, 1280))
im.save('/tmp/vision_input.jpg', quality=85)
```

3. **调用 ollama**:
```bash
IMG_B64=$(base64 -w0 /tmp/vision_input.jpg)
curl -s --max-time 180 http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"qwen2.5vl:3b\",
  \"prompt\": \"请用中文详细描述这张图片的内容:主体是什么、有什么文字、什么颜色、什么风格。如果是表情包或梗图,说明它表达的情绪。\",
  \"images\": [\"$IMG_B64\"],
  \"stream\": false
}" | jq -r .response
```

4. 把返回描述融入回复。识别结果只是参考,语气仍按聊天人设来。

## Pitfalls

- **内存不足**:7.4G 内存机器只跑 3b;7b 会 OOM 或卡死。OLLAMA_MAX_LOADED_MODELS=1 防多模型同时加载。
- **代理**:ollama pull 必须带 `HTTPS_PROXY=http://127.0.0.1:7890`(本机访问外网全靠 7890 代理)。
- **超时**:CPU 上 3b 单张图约 20-60 秒,curl 设 `--max-time 180`。
- **服务没起**:`ollama serve` 需在跑;检查 `curl http://127.0.0.1:11434/api/tags`。
- **大图**:>2000px 先缩到 1280,否则又慢又费 token。
- 识别不确定时如实说"看起来像X,但我不太确定",不要编造细节。

## OCR 用途(读 PDF 书籍)

- 扫描版 PDF:用 pymupdf 渲染页面为 PNG → 本 skill 识别文字
- 比 tesseract 强:中文识别率高,能理解版面
