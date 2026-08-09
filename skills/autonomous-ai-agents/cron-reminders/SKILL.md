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

## Pitfalls

- 用户说"没收到提醒"时:先看输出文件确认是否 silent(空输出=静默,非故障),再看 job 状态。
- 别把 cron 输出当会话记忆;也别把"用户提起的提醒内容"当自己发过——两者都先查证。
- 修改脚本后手动跑一次验证:`python3 ~/.hermes/scripts/<script>.py`(no_agent 语义:有输出=会发,无输出=静默)。
