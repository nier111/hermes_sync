# 本机 cron job 全量清单(2026-08-13 从 ~/.hermes/cron/jobs.json 提取)

排查 cron 问题时的速查表。jobs.json 是权威来源(`python3 -c "import json;print(json.load(open('~/.hermes/cron/jobs.json')))"`),本表会过时,以它为准。

| job_id | 名称 | schedule | 模式 | 说明 |
|---|---|---|---|---|
| 7ac02d9bcb2a | 记忆同步 | every 30m | no_agent 脚本 | ~/.hermes/scripts/sync-memory.sh,git 同步 memories/ 与 skills/;无变更静默 |
| 3154253e4f94 | arch-每日更新简报 | 0 14 * * * | agent | Arch Linux 新闻 RSS 简报 |
| ac85cd45a236 | 水杨酸到货提醒 | once 2026-08-08 | agent | 一次性,已过期 |
| ccc46651dc40 | 每晚护肤打卡 | 0 21 * * * | agent | 按日期奇偶决定水杨酸是否用,已 attach_to_session |
| 0c2bb1bebf4a | 断网自愈检查 | 35 6 * * * | agent | 宿舍 00:00-6:30 断网的自愈 |
| cfcbc1ce0aa5 | 南京下雨提醒 | every 120m | no_agent 脚本 | weather_check.py,降水≥50% 才提醒 |
| 4307651365be | 热梗更新 | 0 9 * * 1 | agent | 每周一 B站热榜提取热梗,写 shared/hot-memes.md |
| 04eaefceb378 | 跨Profile同步 | every 180m | agent | Kubo(gf profile)记忆 → shared/user-preferences.md |
| 331f6a9f968d | 每日自学 | 0 10,18 * * * | agent | 抓 GitHub trending/HN/嵌入式/AI 资讯 → shared/knowledge-base.md 按日期追加 |
| 71ce92627d49 | 趣事发报 | 15 10,18 * * * | agent | 读 knowledge-base.md 今日条目,挑 1 条趣闻女友语气发;无趣→"今天没什么特别的捏" |

## 知识库流水线(每日自学 → 趣事发报)

- 10:00/18:00 每日自学写入 `~/.hermes/shared/knowledge-base.md`;15 分钟后趣事发报读取,只取"今天"的条目。
- 2026-08-13 事故:knowledge-base.md 曾是指向 `/tmp/test-kb.md` 的符号链接,目标被清理后读取方拿到空内容。修复:rm 符号链接 + touch 真实文件。
- 每日自学 job 曾长期无 output 目录(= 从未跑过),趣事发报因此一直读不到内容——先查输出目录再怀疑内容生成。
