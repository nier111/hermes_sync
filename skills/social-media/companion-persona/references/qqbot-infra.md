# Hermes QQ Bot 基础设施运维

## 多账号支持

**当前限制：Hermes gateway 只支持单个 QQ Bot 实例。**

源码分析（gateway/config.py L1508-1511，gateway/run.py L2311）：
`config.platforms` 是 `Dict[Platform, PlatformConfig]`，key 是平台枚举值（如 `Platform.QQBOT` = `"qqbot"`），dict key 唯一，因此每个平台类型只有一个配置槽。

adapter 代码（gateway/platforms/qqbot/adapter.py L191）有 `multi-instance disambiguation` 注释，说明开发者预留了方向，但配置层尚未支持多实例。

**多账号变通方案：Hermes Profiles**

每个 profile 有独立的 config.yaml、.env、sessions，可以跑各自的 gateway：

```bash
# 默认号
hermes --profile default gateway run

# 二号
hermes profile create qqbot2
# 编辑 ~/.hermes/profiles/qqbot2/.env 填入不同的 QQ_APP_ID / QQ_CLIENT_SECRET
hermes --profile qqbot2 gateway run
```

代价：每个 gateway 占用 ~130M 内存，本机 7.4G 总内存需评估。

## Watchdog 自动恢复

### 问题

宿舍 00:00-6:30 断网期间，QQ WebSocket 断开后 gateway 无法自动恢复。
日志特征：`[QQBot:1905362897] Still not connected after 15s`
重启 gateway 秒好，但不重启就一直卡住。

### 方案

脚本位置：`~/.hermes/scripts/qqbot-watchdog.sh`

检查逻辑：
1. 读 gateway.log 最近一条 qqbot 状态行
2. 若 "Not connected" → `systemctl --user restart hermes-gateway`
3. 若 "Connected/Ready" 且时间在 10 分钟内 → 正常
4. 其他情况（状态超 10 分钟无更新）→ 重启保底

定时器（systemd user timer）：`~/.config/systemd/user/hermes-qqbot-watchdog.*`

```ini
# 只在断网恢复后触发，不频繁轮询（凌晨踹不活）
OnCalendar=*-*-* 06:35:00   # 断网结束后 5 分钟
OnCalendar=*-*-* 12:00:00   # 中午补刀
Persistent=true             # 若机器 6:35 未开机，开机后补跑
```

部署：
```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-qqbot-watchdog.timer
```

## 相关命令速查

```bash
# 查看 gateway 状态
systemctl --user status hermes-gateway

# 查看 QQ 连接日志
grep -E "qqbot.*(Connected|Not connected|Ready)" ~/.hermes/logs/gateway.log | tail -10

# 手动重启
systemctl --user restart hermes-gateway

# 查看 watchdog timer
systemctl --user list-timers hermes-qqbot-watchdog.timer
```
