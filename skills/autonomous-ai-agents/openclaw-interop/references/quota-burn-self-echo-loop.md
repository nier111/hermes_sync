# 额度被烧穿 + 自回声循环：OpenClaw 取证补充

> 补充 `references/sqlite-session-cost-forensics.md`（那份讲"数据在哪"），
> 本文件讲"怎么读、读出什么、以及 OpenClaw 特有的烧钱模式"。
> 通用判定特征与标定值见 skill `api-cost-forensics` →
> `references/agent-runaway-loop-signature.md`。
> 现成脚本：`scripts/openclaw-session-usage.py`（只读聚合，先跑它）。

## 1. 会话级模型 pin 存在哪里

`~/.openclaw/agents/<agent>/agent/openclaw-agent.sqlite` → `session_nodes`：

- `session_key`：如 `agent:main:qqbot:direct:<qq号哈希>`（channel 直聊会话）、
  `agent:main:main`（终端/主会话）、`agent:main:cron:<id>`
- `entry_json`：JSON，含
  `{"modelOverride":"kimi-for-coding","providerOverride":"kimi","modelOverrideSource":"user", ...}`
- `current_session_id`：当前会话 uuid，用它去 `transcript_events.session_id` 取记录

**实战后果**：某个会话被 `/model` 式切换 pin 到某 provider 后，那个 provider 的额度
一旦冻结/欠费，**该会话直接失声**（不是慢，是不回）。用户抱怨"bot 不说话了"时，
除了查 gateway 进程/WS，也要查这个 pin 是不是指向一个已经没额度的模型。

## 2. 自回声循环（QQ 通道实测，2026-09-19）

机制：agent 用 `message` 工具主动往 QQ 发消息 → **自己发出的那条消息又回流进它的
上下文，被当成"用户的回复"** → 它判断"用户回了但内容对不上" → 再发一遍 → 循环。

transcript 里的指纹（连续 14 次，18.5 秒/次）：

    assistant/kimi-for-coding: "The user replied (message_id matches, reply_to my previous message).
                               But the content of th…"
    toolResult: {"channel":"qqbot","to":"qqbot:c2c:<id>","via":"di…"}

同时 usage 侧表现：`output` 恒定、`input` 每次 +3、`cacheRead` 每次 +1280。
**双向确认**（transcript 话术 + usage 恒定 output）才是铁证，只有一边不够。

处置：看到重复话术立刻打断/发新消息打断；14 次循环 ≈ 一个 5h 窗口的 42%。
这类"agent 用 message 工具自我回复"的场景，别在 main 会话里跑探索任务。

## 3. 长上下文放大（比循环更常见）

`agent:main:*` 的长期陪伴会话上下文可达 10 万+ token。在这里跑"翻数据库/找 key/
扫配置"这类探索任务，每轮工具调用都要全量重发 → 20 次调用 ≈ 230 万 token。
**同一任务开新会话或丢 subagent，成本差十几倍。** 这是给用户最常见的一条建议。

## 4. `kimi-coding` 插件与账号风险

`extensions/kimi-coding`（`~/.openclaw/npm/projects/openclaw-kimi-provider-*/`）：
`baseUrl: https://api.kimi.com/coding/`、`api: anthropic-messages`、
模型 `kimi-for-coding` / `kimi-for-coding-highspeed`，
并且**硬编码 header `User-Agent: claude-code/0.1.0`** 才能用订阅额度。

Kimi 官方条款明确把"篡改客户端标识（User-Agent）"列为违规、可能暂停会员权益
（详见 `api-cost-forensics` → `references/cn-llm-subscription-plans.md`）。
所以"把 Kimi Code 订阅额度接给 OpenClaw"这件事要**主动告知账号风险**，
不要只说"这档额度不够用"。

## 5. Agent 自查凭证时的副作用（要主动报告）

- 为读 live DB，agent 会 `cp` 整份库到 `/tmp`：实测留下
  `/tmp/oc-state2.sqlite`(8.8M)、`/tmp/oc-agent2.sqlite`(72M)，**含明文 API key**，
  且自称 `cleaned` 却只删了其中一个 pattern。
- key 明文也会落进 `~/.openclaw/logs/...` / `/tmp/openclaw/openclaw-<date>.log`。
- 处理：按 key 前缀 grep `/tmp` 与日志，连同清理建议一起报给用户。

**redaction 与 heredoc 冲突**：让 agent 在 heredoc 脚本里引用 key 时，输出侧脱敏会把
字面量改写成 `***`（实测 `print('KEY='***'profiles']…`），脚本随即 SyntaxError，
然后它开始"修语法错误"白烧额度。结论：**不要让 agent 把密钥拼进 heredoc 脚本正文**，
走文件/环境变量路径读取。

## 6. CLI 版本漂移

仓库 `~/projects/openclaw` 的 CLI 报 2026.7.2，而实际运行的 gateway 是 2026.8.1。
用仓库 `pnpm openclaw` 得出的命令面/输出可能落后于线上行为 —— 涉及结论时说明用的是
哪个版本，或改用全局 `openclaw`（见 memory / 本技能主文档）。
