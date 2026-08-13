---
name: web-search
description: "Use when needing web search without a web_search tool."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [search, bing, wikipedia-api, github-api, huggingface-api, anti-scraping]
---

# Web Search (no web_search tool fallback)

当会话没有 `web_search`/`web_extract` 工具时,用浏览器 + 搜索引擎 API 组合拿搜索结果。curl 直接抓搜索引擎几乎全被反爬,浏览器工具是可靠路径。

## web_extract 与 ddgs 后端不兼容(本机现状)

本机 `web.extract_backend` 是 ddgs,而 ddgs 只支持搜索不支持抓取 —— `web_extract()` 会直接报错 `"DuckDuckGo (ddgs) is a search-only backend and cannot extract URL content"`。**不要重试 web_extract**,改用 curl 抓取(站点配方见 `references/curl-extraction-recipes.md`):
- 国外站:curl 带 UA + 代理 `-x http://127.0.0.1:7890`(GitHub/HN 实测直连也可)
- 国内站(21ic 等)直连即可
- 有 Cloudflare 挑战的站(如 Phoronix)curl 拿不到,直接换浏览器工具

## When to use

- 需要查资料/找名词/验证信息,但工具列表里没有 web_search
- 用户说"你去搜搜看 X"但关键词有歧义时(见 Pitfalls)

## 可靠路径(按优先级)

1. **浏览器 + Bing**(最可靠):
   - `browser_navigate` 打开 `https://www.bing.com/search?q=<query>&setmkt=en-US`(会被重定向到 cn.bing.com,无妨)
   - `browser_snapshot(full=true)` 拿完整结果;结果列表在 main "Search Results" 区,含标题、URL、摘要
   - 国内可访问,反爬最宽松

2. **维基百科 API**(查概念/条目):
   ```
   https://zh.wikipedia.org/w/api.php?action=query&titles=<URL编码标题>&prop=extracts&explaintext=1&format=json&redirects=1
   ```
   - 标题必须 `urllib.parse.quote()` 编码,否则中文报 ascii 错误
   - 必须带 User-Agent,否则 403
   - 外网请求走代理(见 Pitfalls)

3. **代码/模型仓库 API**(查开源项目、模型、角色):
   - GitHub:`https://api.github.com/search/repositories?q=<q>&sort=stars`
   - HuggingFace:`https://huggingface.co/api/models?search=<q>`(返回 JSON;无结果时是 `[]`)

## Pitfalls

- **关键词歧义要先澄清**:同名词可能指向完全不同的东西(实例:"lapwing" = 一种鸟 / VRChat 3D 虚拟形象 / 速记法理论,第一次搜就因没澄清而跑偏)。用户说"搜 X"时,如果 X 有多种含义,先问清类型("是 AI 模型、3D 角色、还是别的?"),或加引号/限定词(`"lapwing" 3d model`)。
- **curl 直接抓搜索引擎会被反爬**:Google/DDG HTML 版/Bing 命令行均返回空或 403。别浪费时间重试,直接上浏览器。
- **r.jina.ai 免费层返回 403**,不要作为抓取兜底。
- **网络**:本机访问外网必须走代理 `http://127.0.0.1:7890`(urllib 用 ProxyHandler,curl 用 `-x`);国内站(百度百科、知乎)可直连。
- 搜索结果页内容在 full snapshot 里,compact 快照只有导航栏没有结果——记得用 `full=true`。
- 搜索"是不是这个"之前,先看结果标题和 URL 域名判断相关性,再下结论。

## 相关

- 识别图片内容用 `local-vision` skill(本地 ollama 视觉模型)。
