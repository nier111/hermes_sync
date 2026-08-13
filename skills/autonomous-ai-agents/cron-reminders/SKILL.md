---
name: cron-reminders
description: "Use when checking or debugging scheduled cron reminders."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [cron, reminders, scheduler, no-agent, attach-to-session]
---

# 定时提醒类 cron 的设计与运维

天气提醒、打卡提醒、到货提醒等定时任务的设计、调试与排查。

## 核心事实:cron 消息不进会话上下文(本会话最大翻车点)

- cron(尤其 no_agent 纯脚本)投递到聊天平台的消息,**用户看得到,但不会进入任何会话的 LLM 上下文**。agent 不知道任务实际发过什么。
- 用户问"你收到/看到我的提醒了吗""最近天气怎么样"时,**先查输出目录再回答**,绝不凭记忆里的旧数据:
  ```bash
  ls ~/.hermes/cron/output/<job_id>/   # 每次触发一个 .md,含实际发送内容或 silent
  ```
- 涉及时间/天气/"最近发生了什么":先 `date` 看当前时间,再查 cron 输出。曾发生:拿 3 天前的"降水 6%"预报回应台风暴雨天,被用户抓包。
- 查看 job 列表/状态:`cronjob action=list`(含 last_run_at / last_status / next_run_at)。

## no_agent 静默模式(有情况才说话)

- 非空 stdout = 投递;空输出 = 完全静默(用户无感知)。适合"有雨才提醒、没雨不打扰"。
- 防刷屏:用状态文件记录上次提醒时间,做冷却(参考 `~/.hermes/scripts/weather_check.py`:阈值 50%、看未来 12h、冷却 5h)。
- 脚本路径放 `~/.hermes/scripts/`,cron script 参数用文件名即可。

## attach_to_session(让用户回复能接上上下文)

- 对 agent 模式 cron 设 `attach_to_session: true`:用户回复该提醒的投递时,回复进入带任务 brief 的会话,agent 不会问"什么打卡?"。
- no_agent 纯脚本提醒开不开均可;agent 模式的打卡/日报类**建议开**。
- 更新示例:`cronjob action=update job_id=... attach_to_session=true name=...`(需至少一个其他字段,如 name)。

## 本机实例

| 任务 | job_id | 模式 | 说明 |
|---|---|---|---|
| 南京下雨提醒 | cfcbc1ce0aa5 | no_agent | weather_check.py,每 2h,输出在 ~/.hermes/cron/output/cfcbc1ce0aa5/ |
| 每晚护肤打卡 | ccc46651dc40 | agent,21:00 | 已 attach_to_session |
| 每日自学 | 331f6a9f968d | agent,10:00/18:00 | 抓取资讯写入 ~/.hermes/shared/knowledge-base.md(按日期追加) |
| 趣事发报 | 71ce92627d49 | agent,10:15/18:15 | 读 knowledge-base.md 挑 1 条趣闻用女友语气发;无趣则发"今天没什么特别的捏" |

完整 job 清单(jobs.json 全量)见 `references/cron-jobs-inventory.md`。

## Pitfalls

- 用户说"没收到提醒"时:先看输出文件确认是否 silent(空输出=静默,非故障),再看 job 状态。
- 别把 cron 输出当会话记忆;也别把"用户提起的提醒内容"当自己发过——两者都先查证。
- 修改脚本后手动跑一次验证:`python3 ~/.hermes/scripts/<script>.py`(no_agent 语义:有输出=会发,无输出=静默)。

## 排查:job 没产出 / 共享文件读不到

- **job 输出目录不存在 = 该 job 从未成功跑过**(或刚建还没到点)。判定顺序:`ls ~/.hermes/cron/output/<job_id>/` → 无目录则读 `~/.hermes/cron/jobs.json`(python3 解析)确认 job 定义和 schedule,别猜。
- **共享文件可能是坏符号链接**:某次 `shared/knowledge-base.md` 是指向 `/tmp/test-kb.md` 的链接而目标已被清理(读出来空/找不到)。排查:`ls -la` 看是否链接 + `readlink -f` 看目标;修法:`rm` 掉符号链接换成真实文件(写入方会继续按原路径写,读者就能读到了)。
- **cron 模式(无用户在场)下 execute_code 默认被策略拦截**(approvals.cron_mode 未开)。终端工具偶发 embedded null byte bug 时,别再指望用 execute_code 绕——改用 read_file / search_files 等普通只读工具完成排查。
