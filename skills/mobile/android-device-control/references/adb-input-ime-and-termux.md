# adb 输入与 Termux 接入的坑(2026-08-06 实测)

## `adb shell input text` 会被手机输入法(IME)拦截

在装了中文/第三方输入法的手机上(本会话 VNE-AN00,Android 12):
- `adb shell input text "..."` 注入的文本可能落到错误的焦点,或被 IME 完全吞掉;
- `input keyevent 66`(回车)可能触发无关动作(实测:AVNC 里回车跳进了"手势与缩放"设置页);
- 注入后截图看到的常常是输入法键盘界面,而不是终端/输入框收到文字。

处理办法(按优先级):
1. 截图 → 看清焦点实际在哪 → 重新 tap 正确的输入区 → 再注入;
2. 若焦点问题反复(终端模拟器、搜索栏这类自定义视图),**请用户手动敲这一条命令**——比无限重试快得多;
3. `uiautomator dump` 对自定义视图(终端、搜索栏)经常只返回空/单条 text,坐标靠截图估算。

## Termux 接入(adb 视角,已验证事实)

- 包名:`com.termux`(`adb shell pm list packages | grep termux`)。
- Termux 的 Linux 用户:`adb shell ps -A | grep termux | awk '{print $1}'`(实测 `u0_a189`)——`ssh -p 8022 <该用户名>@127.0.0.1` 需要它。
- **SSH 接入必须用 `adb forward`,不是 reverse(实测踩坑)**:sshd 在手机上,是电脑要连手机,所以 `adb forward tcp:8022 tcp:8022`(电脑 localhost:8022 → 手机 localhost:8022)。用 `adb reverse` 会让手机端 8022 被反向转发占用——症状:(a) 手机上的 `sshd -ddd -p 8022` 报 `address already in use`;(b) 电脑 ssh 连上 TCP 后立刻 `kex_exchange_identification: Connection closed by remote host`。方向记忆:**谁的服务谁在另一端**——服务在电脑(wayvnc/代理)用 reverse(手机访问电脑);服务在手机(sshd)用 forward(电脑访问手机)。
- Termux sshd 首次运行:`pkg install openssh` 后可能缺 host key 起不来,先 `ssh-keygen -A` 再 `sshd`。确认监听:手机端 `cat /proc/net/tcp | awk '$2 ~ /:1F56/'`(8022=0x1F56,注意是手机视角,adbd shell 可读)。
- 密码登录:`sshpass -p '<pw>' ssh -o StrictHostKeyChecking=no -p 8022 <user>@127.0.0.1`(Arch 需 `pacman -S sshpass`)。
- **把电脑的代理借给手机**:`adb reverse tcp:7890 tcp:7890`,然后在 Termux 里 `export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`。实测必用场景:Termux 的 `proot-distro install ubuntu` 从 GitHub 拉 rootfs,国内网络直连报 `Network error: <urlopen error [Errno 101] Network is unreachable>`,走该代理后成功。反向:电脑访问手机服务同理用 forward。
- **RunCommandService 不可用**(实测):`adb shell am startservice -n com.termux.app/.RunCommandService -a com.termux.RUN_COMMAND --es com.termux.RUN_COMMAND_PATH ...` 报 `Error: Not found; no service started`——普通安装下无法通过 adb 无头执行 Termux 命令。备选:UI 输入(见上,受 IME 影响)或让用户手动敲。
- 注意:`/data/data/com.termux/...` 非 root 不可读,别用 `ls` 探测。
