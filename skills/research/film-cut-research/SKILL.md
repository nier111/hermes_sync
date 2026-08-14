---
name: film-cut-research
description: "Use when hunting rare film cuts, TV re-edits, or fan edits."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [film, video, torrent, research, subtitles, rare-cuts]
---

# 稀有片源/剪辑版调研

用户找特定电影版本(导演剪辑版/电视剧重剪版/加长版/粉丝剪辑)、稀有实体碟或字幕时用这套流程。核心:**先分清版本,再按渠道逐个验证,别凭印象给链接**。

## 步骤

1. **版本去重**:先确认该片存在几个同名版本(例:教父"七小时版"有 1977 NBC 版 434min 与 2021 Paramount+ 版 386min,渠道完全不同)。查豆瓣条目(确认中文名/年份/片长/简介)和 Wikipedia(英文名+别名,如 The Godfather Saga / A Novel for Television / The Complete Epic)。豆瓣移动端 m.douban.com 用手机 UA 可 curl 到,电脑版被反爬。
2. **官方流媒体状态**:JustWatch 按精确标题搜(`https://www.justwatch.com/us/search?q=...`),看是否 "not available for streaming"、在哪个区。很多重剪版只在特定平台短暂上线(2021 教父重剪版只在 Paramount+ 上过,现已下架)。
3. **BT/磁力**:用已知发布名搜索引页(如 rarbg 时代命名 `X.UNCENSORED.EXTENDED.720p.HDTV.x264-BATV[ettv]`),对索引页 curl 后用正则 `magnet:\?xt=urn:btih:([a-f0-9]{40})` 抽 40 位 hash,**hash 必须来自实际抓到的页面,不编造**。可靠索引:limetorrents.fun、kickasstorrents.ee、torrentdownload.info、scnsrc.me、torrentquest.com。1337x/btdig 有 Cloudflare/captcha。
4. **俄站**:rutracker.org(需注册,浏览器能开,curl 被 Cloudflare 拦)。俄站常有 DUB+Sub 的完整版。
5. **中文渠道**:贴吧帖(个人整理好的夸克/网盘资源,通常要私信;curl 被"安全验证"拦,让用户浏览器开)、网盘搜索站(zysou.com、alipanso.com 阿里云盘)、Telegram 资源频道(如 Yiove)。
6. **字幕**:opensubtitles.org 按 imdb 电影 id 搜(`idmovie-xxxxxx`;Anubis PoW 拦 curl,浏览器可开)、subtitlecat.com。
7. **实体/压制碟(收藏向)**:bddvdx.com、eBay 搜片名。
8. **预期管理**:明确告知"无官方蓝光/正版流媒体"和画质上限(老 TV 重剪版通常只有 720p HDTV 修复/AMC 播出版),别让用户期待 4K。

## 陷阱

- ddgs web_search 遇 `InvalidURL: Invalid port` → 环境里 all_proxy 指向 socks5,subprocess 前把 ALL_PROXY/all_proxy/HTTPS_PROXY/HTTP_PROXY 大小写六个变量统一覆写为 `http://127.0.0.1:7890`。
- web_extract 在 ddgs 后端不可用,抓页面用 curl 直连;**必须加 `--compressed`**,否则 gzip 响应在 text=True 解码时崩 `UnicodeDecodeError: 0x8b`。
- 网盘里的"片名1-3全集"多数是剧场版,认文件名里的重剪标记(UNCENSORED.EXTENDED / Saga / Novel for Television)。
- 中文资源站很多已挂(bteye/dy.town 返回 522/空响应)或被反爬,别死磕,给出浏览器直开的替代并继续下一步。
- B站搜到"全集"标题要先验证:curl 视频页抽 `"videos"` 和 `"duration"`,很多是 11 分钟的片段/短剧农场的假全集。
- 版权:自用收藏提示。

## 参考

- `references/godfather-tv-cut.md` — 教父 1977 电视剧重剪版全部已验证渠道(磁力 hash、字幕 id、实体碟、俄站)。
