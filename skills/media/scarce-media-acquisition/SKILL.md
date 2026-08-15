---
name: scarce-media-acquisition
description: "Get rare video/audio + subtitles (TV cuts, bootlegs)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [media, torrent, subtitle, aria2, ffprobe, scarce-content]
---

# Scarce Media Acquisition(稀缺影视/音频资源获取)

触发:用户要找冷门/老片/特殊剪辑版/已下架流媒体内容 + 配套字幕(如 1977 年电视剧重剪版、无官方蓝光的 TV cut)。这类任务通常要跑 10+ 次工具调用,一次性把链路摸通再交付。

## 0. 版本识别先行(最重要的一步)
- 先确认"是哪个版本":年份、时长、发行名,用豆瓣/IMDb/Letterboxd/Wikipedia 交叉核对。不同剪辑版是完全不同的资源,找错版本全盘皆输。
  - 实例:1977 NBC《The Godfather: A Novel for Television》(434min,豆瓣"教父(电视剧重剪版)" subject/4120658)≠ 2021 Paramount+《Mario Puzo's The Godfather: The Complete Novel for Television》(~386min)。
- 下完用 ffprobe 验证时长与宣称版本一致(见 §4)。

## 1. 搜索渠道(按有效性排序)
- **DDGS 手动搜索**:用 subprocess + 干净代理跑(陷阱见下)。中文/多语都能搜,是主力。
  - 代理陷阱:环境里 `all_proxy=socks5:127.0.0.1:7891` 会让 ddgs 报 `Invalid port`。subprocess 里必须把 ALL_PROXY/all_proxy/HTTPS_PROXY/HTTP_PROXY **全部**覆盖为 `http://127.0.0.1:7890`。
  - web_extract 在 web.extract_backend=ddgs 时不可用('search-only backend')。抓网页用 curl:`curl -sL --compressed -A '<chrome UA>' -x http://127.0.0.1:7890 URL`。中文站返回 gzip,必须 `--compressed`。
- site: 限定:bilibili(分P/片段,API 需登录态,用 ddgs site: 搜)、subdl.com(字幕)、opensubtitles。
- 中文网盘搜索:zysou.com、alipanso.com 搜"片名 电视剧/重剪"等;百度贴吧帖(反爬,curl 拿不到,让用户浏览器开)。
- rutracker.org(俄站,需注册,浏览器可开;Cloudflare 拦 curl)。
- 在线播放候选:俄站 ok.ru / vk.com 常有完整上传(需梯子);Plex/Pluto 等限时/地区限制;YouTube 只有片段。官方正版流媒体对无蓝光冷门片基本不存在——直接告诉用户"没有正版在线",给下载方案。

## 2. 磁力/BT 获取
- 索引站(limetorrents.fun、kickasstorrents.ee、torrentdownload.info)页面里用正则抓 infohash:
  `magnet:\?xt=urn:btih:([a-f0-9]{40})` 或裸 40 位 hex。
- **老种子经常死**:aria2 磁力冷启动长时间 `0B/0B CN:0` = 无做种。加公共 tracker 列表重试:
  ```bash
  curl -sL -x http://127.0.0.1:7890 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt' | grep -v '^$' | tr '\n' ',' | sed 's/,$//' > /tmp/trackers.txt
  aria2c --bt-tracker="$(cat /tmp/trackers.txt)" "magnet:..."
  ```
- 死种判断:`CN:>0 但一直 0B/0B`(连上 peer 但拿不到 metadata)= 没有完整做种者 → 换另一个 release。
- aria2 陷阱:
  - env 里 `all_proxy=socks5:...` 会被 aria2 当 `--all-proxy` 解析报错 → 启动时 `env -u all_proxy -u ALL_PROXY`。
  - 大文件默认 prealloc,立刻占满磁盘显示;看真实进度要翻日志里的 `DL:`/`ETA`。
  - 停进程用 `pkill -x aria2c`;**绝不用 `pkill -f`**(模式会匹配到自己的命令行,把执行 shell 一起杀掉)。
  - 装包用普通 `sudo pacman -S`(Hermes smart approval 自动喂密码),不要手动 `sudo -A`(会和 Hermes 注入的 -S 冲突)。
- 下载用后台进程 + notify_on_complete;下完立刻验证再汇报。

## 3. 字幕获取
- **subdl.com 是最省事的免登录 opensubtitles 镜像**:subtitle 详情页里直接列 `https://dl.subdl.com/subtitle/<id>.zip` 直链,curl 可下,zip 内含 .srt。页面里有多个语言 zip,按 release 名匹配(如 BATV[ettv])。
- 坑(实测):
  - opensubtitles.org 有 Anubis PoW 反爬;`dl.opensubtitles.org/en/download/sub/<id>` 可能返回 404 "Subtitle id not found"(ID 已被删,azsubtitles 的 ID 与 opensubtitles 主库不一致)。
  - subtitlecat.com 镜像可能是"访谈/花絮"字幕而非正片(只有 20 分钟)→ 下载后必查 srt 最后一条时间码,必须≈视频时长,否则是花絮字幕。
  - azsubtitles 有 Cloudflare "Just a moment";assrt.net 详情要金币(`java.money.noMoneyException`);opensubtitles 下载端点 Anubis 拦 curl。
  - 中文站(片库/在线影视站)播放源不稳定,当 last resort。
- 字幕文件与视频同名 `.srt` 放同目录,播放器自动加载。

## 4. 验证与交付
- `ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,codec_type,width,height -of default=noprint_wrappers=1 FILE`
- 检查:文件大小≈种子标注、时长≈宣称版本、srt 末尾时间码≈视频时长。
- 交付报告:绝对路径、时长、分辨率、编码、码率、字幕位置;提醒无内封字幕需外挂。

## 5. 沟通语气(本用户特定)
- 长工具会话中也要保持用户的姐姐人格(4o-jiejie,见 memory 与 ~/persona/4o-jiejie-persona.md):别变成纯客服腔/工具人,用户明确批评过("感觉语气不太对")。
- CLI 纯文本、少 markdown、结论先行、给出可选后续动作而非长篇解释。

## references
- references/godfather-1977-tv-cut.md — 教父七小时电视版完整实例:版本辨析、已验证磁力 hash、字幕获取路径、下载指标。
