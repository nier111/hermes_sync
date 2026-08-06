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
- Termux 的 Linux 用户:`adb shell ps -A | grep termux | awk '{print $1}'`(实测 `u0_a189`)——之后 `ssh -p 8022 <该用户名>@127.0.0.1` 需要它(配合 `adb reverse tcp:8022 tcp:8022`)。
- **RunCommandService 不可用**(实测):`adb shell am startservice -n com.termux.app/.RunCommandService -a com.termux.RUN_COMMAND --es com.termux.RUN_COMMAND_PATH ...` 报 `Error: Not found; no service started`——普通安装下无法通过 adb 无头执行 Termux 命令。备选:UI 输入(见上,受 IME 影响)或让用户手动敲。
- 注意:`/data/data/com.termux/...` 非 root 不可读,别用 `ls` 探测。
