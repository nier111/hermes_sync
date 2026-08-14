# OpenClaw 搜索卡住的诊断与恢复（2026-08 验证）

## 症状

OpenClaw agent 执行联网搜索查询时"卡住"，CLI 侧表现为 `timeout 90s` → exit 143，
或长时间无输出。但 gateway 本身是好的（端口 18789 返回 200，模型调用正常）。

## 根因

OpenClaw 的联网搜索后端是 **DuckDuckGo Lite**（`https://lite.duckduckgo.com/lite/`）。
在当前网络环境下每次请求 30 秒超时（日志关键词 `fetch-timeout`）。
一次搜索查询可能反复尝试 DDG-Lite，累计超过外部 timeout，看起来像"挂了"。

## 诊断（看日志，不瞎猜）

```bash
tail -50 /tmp/openclaw/openclaw-$(date +%F).log
```

按关键词定位子系统：

| 日志关键词 | 含义 |
|---|---|
| `fetch-timeout` + `url=...lite.duckduckgo.com/lite/` | 搜索后端 DDG-Lite 超时（根因） |
| `provider-transport-fetch` + `status=200` | 模型调用正常（deepseek 是好的） |
| `embedded run failover decision` | agent 出错/中止（failover） |
| `tool policy removed` | 运行时 allow-list 移除了工具 |

判据：看到 `fetch-timeout` 但 `provider-transport-fetch status=200` → 是搜索超时，不是 gateway 崩溃，也不是模型故障。

## 恢复

```bash
systemctl --user restart openclaw-gateway.service
```

要点：

- **活的服务是用户级** `~/.config/systemd/user/openclaw-gateway.service`。
  系统级 `/etc/systemd/system/openclaw-gateway.service` 是废弃的 podman 配置，长期 `failed`，忽略它。
- 重启后**等 `[gateway] ready` 出现在日志里再探测**；启动过程中端口会短暂返回 000/502（约 20-30 秒）。
- 确认恢复：`curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/` 返回 200，
  且日志出现 `[gateway] http server listening`。

## 别急着下"坏了"的结论

OpenClaw 有 fallback：DDG-Lite 超时后，它仍可能通过其他数据源回答
（例如音乐类问题 fallback 到 MusicBrainz）。一次"看起来卡住"的搜索查询，
通常在 DDG 超时后 30-60 秒内完成。给足预算（>90s），别在 90s 就 kill 并判定"搜索用不了"。

## 教训（通用）

遇到服务/工具卡住，先看日志定位子系统，再重启恢复——**只诊断不修复是不完整的**。
用户明确要求过：卡住就重启试试，别急着下结论。
