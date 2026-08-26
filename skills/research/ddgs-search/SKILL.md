---
name: ddgs-search
description: "Use when web search needed but web_search tool unavailable."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [search, ddgs, duckduckgo, fallback]
---

# DDGS 手动搜索(web_search 不可用时的 fallback)

当会话里没有 `web_search` 工具(工具集在会话开始时固定,中途装的后端要新会话才生效)时,用本方法手动搜索。

## 前置(已完成,无需重复)

- `ddgs` 包已装入 hermes venv:`uv pip install --python ~/.hermes/hermes-agent/venv/bin/python ddgs`
- config 只设搜索后端:`hermes config set web.search_backend ddgs`
- **禁止设置 `web.backend=ddgs`**:ddgs 只支持搜索,共享 backend 会把 `web_extract` 也错误路由到 ddgs。提取后端使用 `web.extract_backend=local-extract`。
- 代理在 `~/.hermes/.env`:`HTTPS_PROXY/HTTP_PROXY/ALL_PROXY=http://127.0.0.1:7890`

## 搜索命令(必须带代理环境变量,DuckDuckGo 国内被墙)

```python
import subprocess, os
env = dict(os.environ)
env['HTTPS_PROXY'] = 'http://127.0.0.1:7890'
env['HTTP_PROXY'] = 'http://127.0.0.1:7890'
code = '''
from ddgs import DDGS
with DDGS(timeout=10) as c:
    for r in c.text(QUERY, max_results=8):
        print("-", r.get("title",""))
        print(" ", r.get("href",""))
        print(" ", (r.get("body") or "")[:120])
'''
r = subprocess.run(['/home/sato/.hermes/hermes-agent/venv/bin/python', '-c', code.replace('QUERY', repr(query))],
                   capture_output=True, text=True, timeout=45, env=env)
print(r.stdout)
```

## Pitfalls

- **必须带代理**:不带 HTTPS_PROXY 会超时(约 10s 每请求,DDG 被墙)。
- **子进程方式**:ddgs/primp 可能阻塞 GIL,Hermes 官方 provider 也用子进程隔离。手动调用时同样用 subprocess,别在主进程 import 调用。
- **中文搜索**:ddgs 对中文支持良好(实测"水月雨 Edge 耳机"秒出结果)。
- **限流**:连续多次搜索可能被 DDG 暂时限制,间隔几秒再试。
- **终端工具 bug**:本机 terminal 工具可能报 `embedded null byte`(lifecycle_guard 解析 bug),用 execute_code 跑 subprocess 绕开。

## 配置验证

```bash
hermes config get web.backend   # 应为 ddgs
```
