---
name: volcano-ark-doubao
description: "Use when user sends images / needs VLM analysis (screenshots, schematics, memes, OCR) — DOUBAO VLM FIRST, faster than local ollama. 用户发图识图优先调用本skill,勿用本地CPU模型。"
version: 1.0.1
author: Hermes Agent
license: MIT
---

# Doubao (火山方舟 / Volcano Ark) API

ByteDance's Doubao models via the Volcano Ark (火山方舟) platform. OpenAI-compatible
chat/completions endpoint. Use when you want a Chinese-ecosystem model for text tasks
or a cheap VLM for image / circuit-schematic analysis.

## Setup

- Base URL: `https://ark.cn-beijing.volces.com/api/v3`
- Auth: `Authorization: Bearer ark-<key>` (key format starts with `ark-`)
- OpenAI-compatible: `/api/v3/chat/completions` works with a model ID directly.
- Config in Hermes: `hermes config set model.aliases.doubao.provider openai`, then
  `...doubao.base_url https://ark.cn-beijing.volces.com/api/v3`, `...doubao.api_key ark-...`.

## Key gotcha: endpoint ID vs model ID + 开通 (activation)

- The console creates "推理端点" (inference endpoints) with IDs like `ep-20260812...`.
- You can also call a model ID directly (e.g. `doubao-seed-2-0-lite-260428`), BUT the
  model must first be "开通" (activated) in the console — otherwise you get
  `NoAvailableModel` or `has not activated the model <id>`.
- A freshly created endpoint reports `NoAvailableModel` until the model finishes
  deploying (console shows 运行中/健康).
- `/api/v3/models` lists every model with a `status` field (`Shutdown` / `Retiring`;
  models WITHOUT a status field are active). Use this to find a live model name.

## VLM (vision) for schematics / images

- `doubao-seed-2-0-lite-260428` accepts `text` + `image` + `video` input. It reads
  circuit schematics well: identifies ICs, traces topology (H-bridge, PWM logic
  chain, dead-time resistor networks), and explains function, not just part numbers.
- Call pattern: OpenAI-style `messages` with an `image_url` content part; a base64
  `data:image/png;base64,...` URL works directly.

## Schematic-reading workflow (tested end-to-end)

1. `pdftotext -layout file.pdf -` → component names / net labels / values (fast, but
   jumbled and no topology).
2. `pdftoppm -png -r 150 file.pdf out` → one PNG per page.
3. Feed each page to the Doubao VLM → topology, signal chain, module breakdown.
4. Cross-verify: the VLM makes small numeric errors (e.g. misread a resistor value).
   Use the `pdftotext` output to correct values / reference designators.

## Caveats

- Text answers hallucinate on niche/oral facts (Chinese internet memes: ~65% accurate;
  fabricates plausible origins for the rest). Use only as a first draft, verify against
  authoritative sources (百科/知乎/贴吧/B站标题).
- Local `qwen2.5vl:3b` on a ~2GB-VRAM box is too slow for schematic pages (times out);
  the Doubao VLM is the reliable alternative. Doubao response is slow (~70-95s per
  schematic page); budget for that.
- This model runs through the user's paid Ark balance — for throwaway/experimental
  queries, prefer a free OpenRouter VLM or the local model if speed is irrelevant.
