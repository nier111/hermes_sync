---
name: linux-bluetooth-pairing
description: Use when Bluetooth pairing fails or GUI dialog is missing.
---

# Linux 蓝牙配对与连接排障

## 触发场景
- `bluetoothctl pair` 报 `AuthenticationFailed`,或手机端显示"配对码不正确/不响应"
- GUI(blueman-manager)点配对后没有确认框、manager 卡住不响应
- 设备能扫描到但一直连不上(先看 `bluetoothctl info <MAC>` 的 Paired 状态)
- Google 跨设备通行密钥(CaBLE)扫码认证问题 → 见 `references/google-cable-passkey.md`

## 核心坑(已实测)
1. **bluetoothctl 单命令模式 agent 不持久**:
   每次 `bluetoothctl pair xx` 都是独立进程,agent 注册随进程结束而消失。
   配对请求需要 agent 应答确认码,没人应答 → 手机端显示"配对码不正确"/AuthenticationFailed。
2. **管道喂命令无法应答确认**:
   `{ echo pair ...; } | bluetoothctl` 也会卡在 `[agent] Confirm passkey NNNNNN (yes/no):` 等输入,命令流不会自动回 yes。
3. **default agent 全局只有一个**:
   CLI 会话注册 default agent 后,blueman-applet 的图形确认框不再弹出(GUI 表现为"没有确认的地方")。
   配对完成后必须退出 CLI 会话(quit),把 agent 主导权还给 GUI 管理器。

## 正确配对流程(已验证可用)
1. 状态检查:
   ```
   systemctl status bluetooth --no-pager
   bluetoothctl list && bluetoothctl show
   bluetoothctl devices
   bluetoothctl info <MAC>   # 看 Paired/Bonded/Trusted/Connected
   ```
2. 开持久交互会话:terminal(background=true, pty=true) 启动 `bluetoothctl`
3. 在会话内依次提交:
   ```
   agent on
   default-agent
   scan on
   pair <MAC>
   ```
4. 轮询输出,看到 `[agent] Confirm passkey NNNNNN (yes/no):` 后,
   用 process action=submit 发送 `yes`;同时提醒用户手机端确认同一数字。
   (SSP numeric comparison 两端数字必须一致)
5. 配对成功后依次:
   ```
   trust <MAC>
   connect <MAC>
   ```
6. 收尾:会话内 `quit` 退出,释放 default agent。

## GUI(blueman)配对机制
- blueman 的确认框由后台 **blueman-applet** 弹出(屏幕中央/托盘附近),不是 manager 窗口里的按钮——GUI 没有"填 yes"的地方,只有图形对话框。
- GUI 不弹框先按序查:
  1. default agent 是否被 CLI 会话占用(最常见)
  2. blueman-applet 是否在跑(`pgrep -a -f blueman`)
  3. 切 workspace / 看托盘通知,找漏掉的对话框
- Hyprland/Wayland 下 applet 日志有 "Only X11 platform is supported" 插件警告属正常,不影响认证。
- 排查时注意:用户会话里已注册的 CLI agent 会"吞掉" GUI 的配对请求,这是排障时必须先排除的。

## 验证
```
bluetoothctl info <MAC>   # 期望 Paired/Bonded/Trusted/Connected 均为 yes
```

## 参考
- `references/google-cable-passkey.md` — Google 跨设备通行密钥(CaBLE)扫码认证排障、FIDO QR、passkey 域名绑定、g.co 短链接实测结果
