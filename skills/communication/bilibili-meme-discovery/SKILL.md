---
name: bilibili-meme-discovery
description: "Find Chinese memes on Bilibili. Search slow, avoid 412."
version: 1.0.0
---

# Bilibili Meme Discovery

Discover trending Chinese internet memes from Bilibili video titles and comments.

## Core Principle: Slow Down

Bilibili API returns 412 (Precondition Failed) when you request too fast.
**Always sleep 5+ seconds between API calls.** This is the single most important rule.

## Workflow

### 1. Search for meme compilation videos

Use the browser (more reliable than direct API for search):
```
browser_navigate → https://search.bilibili.com/all?keyword=热梗&order=click
```

Or use the API with 5s delay:
```
sleep 5
curl -s -H "User-Agent: Mozilla/5.0..." "https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=热梗"
```

### 2. Extract candidate memes from titles

Good channels for meme compilations:
- 梗百科 (official meme wiki channel)
- 江湖百晓生呀 (regular hot meme roundups)
- Any video with "盘点近期网络热梗" in title

Extract meme names directly from video titles. These are reliable because:
- The titles list real, trending memes
- Unlike LLM-generated lists, these come from real content creators

### 3. Get video details (optional, for descriptions)

```bash
sleep 5
curl -s -H "User-Agent: Mozilla/5.0..." "https://api.bilibili.com/x/web-interface/view?aid={aid}"
```

Video descriptions sometimes contain meme explanations.

### 4. Get comments (for usage examples)

```bash
sleep 5
curl -s -H "User-Agent: Mozilla/5.0..." "https://api.bilibili.com/x/v2/reply?type=1&oid={aid}&pn=1&sort=2"
```

Most videos only have ~3 hot comments. Sort modes: 0=time, 1=hot, 2=hot(default).

### 5. Query Doubao for initial explanations

```bash
curl -s "https://ark.cn-beijing.volces.com/api/v3/chat/completions" \
  -H "Authorization: Bearer $ARK_API_KEY" \
  -d '{"model":"doubao-seed-2-0-lite-260428","messages":[{"role":"user","content":"解释以下热梗..."}]}'
```

Doubao's explanations are ~65% accurate. Always flag uncertainty.

### 6. Present candidates for user review

Format: table with | 梗 | 含义 | 日常用法 | 判定 |
User makes final call on inclusion.

### 7. Update dictionary

Write to: `~/.hermes/profiles/gf/skills/gf-stickers/references/hot-memes.md`
Then sync to: `~/.hermes/shared/hot-memes.md`

## Pitfalls

- **412 = too fast.** Not a permanent block. Add 5s delay, retry.
- **Bilibili comment API returns very few hot comments.** Don't expect deep comment mining from compilation videos.
- **Doubao WILL hallucinate for niche/oral memes.** The video title is the ground truth; Doubao is just a first draft.
- **The browser tool is better for search than curl** — Bilibili's search page has less aggressive anti-bot than their API.
