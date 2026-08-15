---
name: scarce-media-subtitles
description: 找冷门影视片源(BT磁力+tracker)和字幕(subdl等镜像)时用。
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [torrent, subtitle, bt, aria2, media]
---

# 冷门影视资源 + 字幕获取

触发:找老片/冷门片源(如 1977 教父电视剧重剪版)、七小时重剪版、配字幕(opensubtitles 被 Anubis 反爬时)。

## 片源
1. 确认版本:豆瓣条目(movie.douban.com/subject/<id>,移动版 m.douban.com 可 curl,电脑版反爬)确认年份/片长/简介;注意同名不同版(1977 NBC 版 vs 2021 Paramount+ 重剪版)。
2. 搜索:ddgs(带 http 代理 7890,清掉 ALL_PROXY 的 socks5 条目)搜"中文名+年份"或"英文名+版本关键词"。
3. 磁力 hash:从 torrent 索引站页面(limetorrents.fun、kickasstorrents.ee、torrentdownload.info)regex 抓 `magnet:\?xt=urn:btih:[a-f0-9]{40}`;rarbg 时代发布名(BATV[ettv] 等)做种者多。
4. aria2 下载(已在 2026-08 装):
   - 磁力冷启动 0B/0B CN:0 → 必须挂公共 tracker:curl ngosang/trackerslist master trackers_best.txt,转逗号分隔 `--bt-tracker="..."`。
   - 停进程用 `pkill -x aria2c`(别用 pkill -f,模式会匹配到自己的 shell 导致自杀)。
   - `env -u all_proxy -u ALL_PROXY` 避免 socks 代理格式解析错误。
   - 死种判断:CN>0 但始终拿不到元数据(0B/0B)→ 换发布版本(同片不同压制)。
   - 后台跑:terminal(background=true, notify_on_complete=true)。
5. 验证:ffprobe -show_entries format=duration 对比预期时长;ls 文件大小对比种子。

## 字幕(opensubtitles 有 Anubis PoW 反爬,curl 不行)
- 首选 subdl.com:免登录,搜索后字幕页直接有 `https://dl.subdl.com/subtitle/<id>-<opensubid>.zip` 链接,批量下载 zip 解压筛选。
  - 筛选:看 zip 内 srt 文件名是否匹配视频发布名(如 ...BATV[ettv].srt)。
  - 陷阱:同名但内容是访谈/花絮(时间轴只有 20 分钟)或非目标语言——用 tail 看最后一条时间码是否接近视频时长。
- subtitlecat.com:opensubtitles 部分镜像,免登录 srt 直链,但可能只镜像了花絮字幕。
- assrt.net(射手网伪):详情需金币,跳过。
- azsubtitles/1337x/rutracker:Cloudflare 拦 curl,浏览器可开。
- 中文网盘(zysou/alipanso)碰运气;识别关键词(文件名含 "Novel for Television"/"Saga" 才是重剪版)。
- 机器翻译英字→中字:DeepSeek 批量(约 3000+ 条,成本几块,需确认用户同意)。

## Pitfalls
- 代理:全部 curl/搜索带 HTTPS_PROXY=http://127.0.0.1:7890;但 aria2 BT 流量不走 http 代理,直接直连。
- 宿舍断网 00:00-6:30,大文件下载避开该时段。
- 文件预分配(15.6G 显示已占盘)≠ 已下载,看 aria2 日志的 DL 速度/已下 MiB。
