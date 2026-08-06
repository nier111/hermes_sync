---
name: vscode-oss-customization
description: "VSCode/Code-OSS customization: backgrounds & plugin quirks."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [vscode, code-oss, customization, background, workbench]
---

# VSCode / Code - OSS 定制与排障

触发:用户要改 VSCode 背景图、装 workbench.html 修改类插件(background、custom-css 等)、遇到 EACCES 权限错误、或插件"装了没效果"。

## 第一步:确认安装形态(决定目录和文件路径)

- Arch 的 `code` 包(extra)是 **Code - OSS**(进程 `/usr/lib/electron42/electron /usr/lib/code/code.mjs`);AUR 的 `visual-studio-code-bin` 才是官方版。
- **Code - OSS 的目录**:配置 `~/.config/Code - OSS/`,扩展 `~/.vscode-oss/extensions/`(注意目录名带空格)。
- 官方版:配置 `~/.config/Code/`,扩展 `~/.vscode/extensions/`。
- 查错目录是此类问题最常见的空转来源 — 先 `ls ~/.vscode-oss/extensions/` 确认插件本体真的在,再谈别的。

## workbench.html 修改类插件的权限坑(EACCES)

- 位置:`/usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html`(root:root 644,普通用户写不了)。
- 报错 `EACCES: permission denied, access '...workbench.html'` 时修复(注意用本机 SUDO_ASKPASS 机制,禁 echo|sudo -S):

```bash
SUDO_ASKPASS=/home/sato/.hermes/askpass.sh sudo -A chown -R sato:sato /usr/lib/code/out/vs/code/electron-browser/workbench/
```

- **pacman 更新 code 包后权限会重置回 root**,需重跑。可提醒用户或做成脚本。
- workbench.html 被插件修改后 VSCode 会弹"安装似乎损坏,请重新安装"通知 — 背景类插件自带 CSS 隐藏它,属正常现象,不是错误。

## shalldie.background 3.0.1 排障(2026-08 实测,open-vsx/GitHub 均无新版)

症状链:分区背景(editor/sidebar)能显示 → 改 `background.fullscreen` 后什么都不显示。

1. **fullscreen 在 Linux 上是坏的**:插件的 `normalizeImageUrls()` 把本地路径转 `vscode-file://vscode-app/...` 协议时生成坏 URL(实测注入 `vscode-file://vscode-app/home/sato/%5Chome%5Csato%5CPictures%5Cayane.jpg` — 路径被替换成反斜杠 + 错误前缀),图片加载失败。这是插件 bug,配置怎么写都没用。
2. **workaround:四区同图** — editor/sidebar/panel/auxiliarybar 配同一张图,视觉等效整窗背景(区域交界可能有细微接缝):
```json
"background.editor": { "images": ["file:///home/sato/Pictures/ayane.jpg"], "opacity": 0.15, "size": "cover", "position": "center", "styles": [], "interval": 0, "random": false }
```
(其余三区同样式同图;`background.enabled: true` 保留)
3. **配置字段(3.x)**:顶层 `images/opacity/size/position/styles/interval/random`。网上老示例里的 `style` 子对象、`useFront` 在 fullscreen 下无效 — 别照抄老配置。
4. **验证注入结果**:`grep 图片名 /usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html` — URL 一眼可辨好坏(带 `\` 或 `vscode-app` 前缀异常即坏)。改配置后需**完全退出 VSCode 重开**(不是 Reload Window),插件在 onStartupFinished 时重新 patch。

## 通用诊断顺序(背景/样式插件"不生效")

1. 确认安装形态 + 正确目录(见上)
2. 插件本体在、未被禁用(`extensions.disabled` 里没有它)
3. 图片文件存在且有效(`file` 命令看格式)
4. workbench.html 的 mtime + 注入内容(插件是否真的写过)
5. 配置键名对照插件 package.json 的 `contributes.configuration.properties`(权威,别信网上的老示例)

## 备注

- 完整踩坑记录(含可复制配置)在用户知识库 `~/projects/HelpListCreatedByAyane/HelpListMD/Vscode/vscodeBackgroundProfile.md`,改机器/重装时可对照。
- 用户偏好:整窗同一张图 > 分区不同图;透明度偏好 0.1~0.25。
