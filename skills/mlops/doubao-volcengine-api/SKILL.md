---
name: doubao-volcengine-api
description: "Use Doubao/Volcano Ark API. Activation, VLM vision, costs."
version: 1.0.0
---

# Doubao / Volcano Ark (火山方舟) API

ByteDance's Doubao models via the Volcano Ark platform. OpenAI-compatible `chat/completions`.

## Endpoint & Auth

```
Base URL: https://ark.cn-beijing.volces.com/api/v3
Auth header: Authorization: Bearer ark-<api-key>
```

API key is created in the 火山方舟 API 中心 (费用中心 + API key 管理). One key covers all models — it is NOT model-specific.

## Setup Pitfalls (read before first call)

1. **Models must be "开通" (activated) before use.** Creating the API key is not enough. In the console 模型列表 each model needs activation. Until then you get `NoAvailableModel` / "Your account ... has not activated the model". Fix: console → 模型列表 → 一键开通 (or per-model 开通).

2. **Model ID vs Endpoint ID — two valid call targets:**
   - Model ID directly (e.g. `doubao-seed-2-0-lite-260428`) — works once activated. PREFER this.
   - Endpoint ID (e.g. `ep-20260812xxxx-lf2qq`) — requires creating an inference endpoint in the console, waiting for it to deploy (健康/green), then passing the endpoint ID as the `model` field. More steps, no benefit for plain use.

3. **Two API shapes both work:**
   - `/chat/completions` — standard OpenAI: `{"model": ..., "messages": [...]}`. Use this for OpenAI-compatible clients (Hermes, etc.).
   - `/responses` — newer: `{"input": [{"role":"user","content":[...]}]}` with `input_text` / `input_image` content types.

4. **Slow responses.** Doubao lite/pro take ~70-95s per schematic page and can exceed 30s curl timeouts. Use `--max-time 180` and cap `max_tokens`. Long batch prompts can exceed 5-minute limits — split into 2 batches.

## Models (as of 2026-08)

| Model ID | Modalities | Notes |
|---|---|---|
| doubao-seed-2-0-lite-260428 | text+image+video | cheapest; reads schematics well; still hallucinates oral memes |
| doubao-seed-2-0-pro-260215 | text+image+video | better but slower, more tokens |
| doubao-seed-2-1-pro / -turbo | text+image+video | newest |

Full list: `GET /api/v3/models` (most older doubao-1.x/seed-1.x are Shutdown/Retiring).

## Vision Capability

doubao-seed-2-0-lite-260428 reads circuit schematics / PCB images exceptionally well — it extracts topology, signal chains, protection mechanisms, and connector pinouts, not just part numbers. Concrete workflow in `references/schematic-reading.md`.

## Hallucination Pattern (critical)

Reliable on STRUCTURED content (schematics, documented facts), but HALLUCINATES on oral/internet memes — fabricates plausible-sounding origins when the true answer isn't in training data. Tested: "我chovy" got three DIFFERENT wrong explanations across lite/pro/turbo (all invented an LOL-player origin). Always cross-check meme/slang explanations against a real source (百度百科, 知乎, B站评论区 via OpenClaw), never trust Doubao's first draft for oral memes.

## Cost (2026-08)

Doubao lite ≈ ¥3/M input, ¥15/M output — cheap for vision/meme queries, negligible per schematic page.

OpenRouter alternatives (separate account + credits):
- `qwen/qwen3.5-flash-02-23` — $0.065/M input, vision, Qwen strong at Chinese+vision — but needs OpenRouter credits (402 without balance)
- `google/gemini-2.5-flash-lite` — $0.1/M input, vision
- `:free` models exist but timeout/rate-limit under load (e.g. nemotron-nano-12b-v2-vl:free → 504 upstream timeout) — unreliable for real work.
