# Hermes QQ Bot 诊断与重启

## 两个 QQ Bot 的区别（别搞混）

| | Hermes qqbot | OpenClaw qqbot |
|---|---|---|
| App ID | 1905362897 | 1903729635 |
| 服务名 | `hermes-gateway` | `openclaw-gateway` |
| 用户口中通常指 | "我的 qqbot" | OpenClaw 那边的 |
| 日志位置 | `~/.hermes/logs/gateway.log` | `/tmp/openclaw/openclaw-*.log` |

用户说"QQ bot 断了"时，**先问清楚是哪个**，大概率是 Hermes 这边的。

## 快速诊断

```bash
# 看服务状态
systemctl --user status hermes-gateway

# 看 QQ 连接日志
grep -i "qqbot" ~/.hermes/logs/gateway.log | tail -10

# 看 systemd journal（如果文件日志没输出）
journalctl --user -u hermes-gateway --since "10 minutes ago" --no-pager | grep -i qqbot
```

典型故障信号：
- `Still not connected after 15s` → WebSocket 断了，重连一直失败
- `live adapter delivery ... failed: Not connected` → cron 任务发不出去

## 修复

```bash
systemctl --user restart hermes-gateway
```

重启后 10 秒内看日志确认：
```bash
grep "qqbot.*connected\|Ready" ~/.hermes/logs/gateway.log | tail -3
```

预期输出类似：
```
✓ qqbot connected
[QQBot:1905362897] Ready, session_id=...
```

## QQ WebSocket 行为

- QQ 服务端每 30 分钟踢一次连接（Session timed out）
- 正常情况 gateway 会自动重连（几秒内恢复）
- 如果长期运行（>2天）后出现"Still not connected"的循环卡死，重启 gateway 秒好
- 根因可能是 token 刷新或 WebSocket 状态机卡住
