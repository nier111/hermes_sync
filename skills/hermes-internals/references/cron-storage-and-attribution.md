# cron 数据的存放位置(以及 state.db 里查不到的那部分)

排查"这条消息是谁发的"时容易走错的第一站。补充 SKILL.md 的 `~/.hermes/` 布局清单。

## cron 不在 state.db 里

- cron job 定义、schedule、last_run_at/last_status:**`~/.hermes/cron/jobs.json`**(单个 JSON,`{"jobs":[...]}`,每个 job 有 id/name/prompt/schedule/deliver/last_run_at)。
- **`~/.hermes/cron/jobs.db` 在本机是 0 字节空文件**;`sqlite3 jobs.db ".tables"` 只报 `Parse error: no such table`。别把它当权威来源。
- 每次触发的实际投递内容:`~/.hermes/cron/output/<job_id>/YYYY-MM-DD_HH-MM-SS.md`(目录不存在 = 该 job 从未成功跑过)。
- `cron/executions.db` 存执行记录;`cron/usage_audit.jsonl` 存额度审计。

## state.db 查到的是"空壳"

cron / 平台侧投递在 `state.db → messages` 里**看不到正文**(assistant 行的 content 长度为 0)。所以:

- 想还原"某条 cron 发过什么"→ 读 `cron/output/<job_id>/`,**不要**查 state.db。
- 想还原"用户看到的那条消息/图片"→ 先查 `cron/output/*` 各 job 的触发时间,再对 `~/.hermes/cache/images/*.jpg` 的 mtime 做秒级比对;吻合即归因。图片 cache 目录的资源在 agent 上下文里可能是不可见的(只以 `MEDIA:` 或附件形式投出)。
- 归因流程与"新建 cron 必须记录动机"的纪律,见 `cron-reminders` skill 的 `references/cron-job-rationale-and-attribution.md`(本文件只讲数据在哪)。
