---
name: multi-agent-orchestration
description: "Run Hermes/Codex/OpenClaw as subprocesses from one app."
version: 1.0.0
---

# Multi-Agent Orchestration

把多个 CLI agent（Hermes / Codex / OpenClaw）编排进一个统一界面或脚本
（例如 Qt GUI、聊天聚合器、调度器）时的子进程集成经验。

## When to use
- 把 Hermes、Codex、OpenClaw 接入同一个聊天 UI / 调度器 / 网关
- 让一个 agent 转调另一个 agent 完成任务
- 需要从外部监控某个 agent 的 token 用量 / 成本 / 会话状态

## 各 agent 的 CLI 集成方式

| Agent | 一次性调用 | 会话保持 | 拿 usage/成本 | 超时建议 |
|-------|-----------|---------|--------------|---------|
| Hermes | `hermes -z "<prompt>"` | `hermes chat -q "<prompt>" --resume <sessionId>` | `-z ... --usage-file <path>` 输出 JSON | 300s（转调时会变慢） |
| Codex | `codex exec "<prompt>"` | 默认 session / `--ephemeral` 隔离 | 无 CLI 接口，只能网页看 | 60s |
| OpenClaw | `pnpm openclaw agent -m "<prompt>"` | `--session-key <key>` | 无 | 660s（联网慢） |

### Hermes 子进程集成的关键接口

- **`hermes -z` 是每次新进程**，没有会话上下文。若要续接历史，用
  `hermes chat -q "<prompt>" --resume <sessionId> --no-restore-cwd`，让 Hermes
  自己维护会话，而不是把历史拼进 prompt。
- **`--usage-file <path>`**（仅 oneshot 模式）：跑完写一个 JSON 报告，字段含
  `input_tokens`（当前上下文 token 数）、`output_tokens`、`total_tokens`、
  `estimated_cost_usd`（估算美元成本）、`model`、`api_calls`。失败也会写，
  管道可据此记账。这是外部程序拿 Hermes 用量/成本的唯一现成接口。
- 上下文占用百分比 = `input_tokens / context_window`。Hermes 自己的 CLI 里
  `/context` 看分类 breakdown，`/usage` 看累计 token 消耗 + rate limit，
  `hermes prompt-size` 看 system prompt / 工具定义的字节开销。
- **DeepSeek 的 context window 是 1M（1,000,000 token），不是 128K**。算
  百分比时分母必须用 1M，否则百分比会错（实测踩坑：拿 128K 除，1.8% 被
  显示成 16%）。核验：`grep context/hermes_tokens ~/.hermes/config.yaml`
  及 Hermes `model_metadata.py` 里的窗口声明，别拍脑袋用 128K。

### 各 agent 的会话保持

- Hermes：`--resume <sessionId>`（sessionId 首次跑完从返回里取，或自己生成）
- OpenClaw：`--json --session-key <key> --message-file <file>`（prompt 走临时文件，
  避免命令行转义）
- Codex：默认在 git 仓库内维护 session；`--ephemeral` 强制一次性隔离

## 陷阱

### 看门狗要按 agent 分层，否则转调慢操作会连坐误杀
本会话根因案例：一个 Qt 聚合器用 60s 看门狗对待所有 agent，Hermes 收到
"唤醒 OpenClaw"的请求后转调 `pnpm openclaw agent`（联网慢，可卡 150s+），
外层 60s 看门狗以为 Hermes 卡死，SIGTERM 杀掉 → 报 "Process crashed"。
Hermes 本身 4s 就回，是被"等待另一个 agent"拖超时的。

教训：
- 会给 agent 发"转调其他 agent / 联网检索"类任务的 agent，超时要放宽
  （Hermes/OpenClaw 300s+，Codex 这种快速一次性的 60s 够）。
- 判断 agent 是否"卡死"要看它是否有输出，而不是简单计时；转调期间
  被调方慢 ≠ 调用方挂了。

### 编排时用 `--resume` 而非塞历史进 prompt
把 24000 字符历史拼进 `-z` 的 prompt 既浪费 token，又丢失 Hermes 自身的
会话状态（memory 写入、tool 结果缓存）。`--resume` 让 Hermes 自己管历史。

### 断网时段别让 agent 做联网转调
宿舍/办公环境定时断网时，联网检索类转调会卡满超时。把"需要联网的活"
和"纯本地活"分开调度，或断网时段禁用联网类 agent 调用。

## 成本架构（本机实测）

- Codex 走 ChatGPT Plus 订阅（OAuth 登录 `codex login`），模型 GPT-5.6，
  不烧 API key 的钱 → 重活/推理/识图优先给它。
- OpenClaw 走同一份 DeepSeek key，中文联网检索强。
- 豆包 VLM 做识图兜底（doubao-seed-2-0-lite，¥3/M 输入）。
- 主 agent（Hermes）只做记忆/调度/编排这类轻活，token 消耗大幅下降。

## 关联

- 各 agent 的详细调用参数：codex / openclaw / hermes-agent（bundled）skill
- 原理图识图工作流：power-electronics-design → references/schematic-analysis-vlm.md
