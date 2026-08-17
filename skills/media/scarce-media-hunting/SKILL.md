---
name: scarce-media-hunting
description: "Use when hunting rare/scarce video content and subtitles."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [media, torrent, subtitle, download, scarce, rare, video]
---

# 稀缺影视资源获取(找片源 + 下载 + 字幕)

用于找冷门/老片/重剪版/地区限定的影视资源。完整实战案例见 `references/godfather-tv-cut-1977.md`。

## 触发条件
- 用户要某个正版平台没有、网上资料少的片(重剪版、老电视剧、冷门修复版)
- 先分清"用户到底要哪个版本"(同名不同版本是最大坑,见下)

## 第一步:版本识别(必做,别跳过)
- 很多片有多个"重剪/电视/导演"版本,先查豆瓣 + IMDB + Wikipedia 确认:
  - 片长/集数(不同版本片长差异巨大,如教父 1977 电视版 434min vs 2021 Paramount+ 版 ~386min)
  - 发行年份、平台(NBC/Paramount+)、别名(Saga / Novel for Television / Complete Epic)
- 豆瓣条目能确认中文圈通行的叫法,IMDB tt ID 用于字幕站搜索
- 别把"剧场版资源"当重剪版交付——网盘/标题里 1-3 合集基本都是剧场版

## 第二步:搜索渠道(web_search 的 ddgs 后端 + 手动 ddgs)
- 本机 `web_search` 可能因代理 `all_proxy=socks5://127.0.0.1:7891` 报 `Invalid port`。修法:execute_code 里 subprocess 跑 ddgs,env 里把 ALL_PROXY/HTTPS_PROXY/HTTP_PROXY 全部覆盖为 `http://127.0.0.1:7890`(见 ddgs-search 技能)
- 搜索词中英各来一轮:中文("片名 电视剧重剪版 网盘/资源")+ 英文(片名 + 关键版本名)
- `site:bilibili.com 片名 版本名` 找 B 站上传(注意区分 11 分钟片段和完整版,用视频页 meta 的 duration 验证)
- 磁力/torrent 索引:limetorrents、kickasstorrents、torrentdownload.info、1337x、rutracker(俄站需注册、Cloudflare 挡 curl)

## 第三步:BT 下载(aria2)
```bash
# 装 aria2(sudo 直接跑,Hermes smart approval 会自动处理密码,别手动加 -A/-S)
sudo pacman -S --noconfirm aria2
# 拉公共 tracker 列表(纯磁力无 tracker 在国内基本连不上做种者)
curl -sL -x http://127.0.0.1:7890 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt' -o /tmp/trackers.txt
TRACKERS=$(grep -v '^$' /tmp/trackers.txt | tr '\n' ',' | sed 's/,$//')
# 后台下载:必须 unset all_proxy(all_proxy=socks5://127.0.0.1:7891 会被 aria2 当 --all-proxy 解析报错)
env -u all_proxy -u ALL_PROXY aria2c --seed-time=0 --bt-max-peers=200 --max-connection-per-server=16 --split=16 --bt-tracker="$TRACKERS" "magnet:?xt=urn:btih:HASH&dn=..."
```
- 下载用 terminal background=true + notify_on_complete=true
- 完成后用 `ffprobe -v error -show_entries format=duration -show_entries stream=codec_name,width,height` 验证时长/分辨率,别只看文件大小

## 第四步:字幕(subdl 免登录镜像优先)
- **opensubtitles.org 本体有 Anubis PoW 反爬,curl 抓不了**;azsubtitles 等站有 Cloudflare;assrt.net 详情页要金币
- **subdl.com 是 opensubtitles 的免登录镜像**,直接给 dl.subdl.com zip 直链:
  1. ddgs 搜 `site:subdl.com <片名> <版本名>` 或直接访问 subdl.com 搜索
  2. 页面里抓 `https://dl.subdl.com/subtitle/<id>.zip` 全部下载(几个 zip 都很小)
  3. **逐个 unzip 检查文件名+语言**:文件名像英文的可能是芬兰语等其他语言(372496 案例),别只看文件名
  4. **验证时间轴**:tail 字幕最后一条时间码,必须接近视频时长。反例:subtitlecat 上同名 BATV 字幕只有 22 分钟,是幕后访谈不是正片
- 其他:subtitlecat.com 是多语言镜像但可能只有特辑字幕;字幕文件与视频同名同目录即可被播放器自动加载
- 意大利语/多语言段:opensubtitles 常有 [Non-English] 单独字幕,但可能只标 "(Speaking Italian)" 不翻译——完整英文字幕才可靠

## 在线播放渠道(当用户问"能不能在线看")
- 官方流媒体:老片/重剪版大多无正版在线(1977 电视版从未上线;2021 版已下架——用 JustWatch 的 US 搜索页验证,curl 可抓)
- 非官方:ok.ru(俄站,有完整 7 小时上传,需梯子,og:video 是 embed 页不是直链;yt-dlp 提取 player params 常失败)、Pluto TV(美区限时免费播出,过季就没了)、YouTube(只有片段)
- 中文盗版影视站(搜狗视频/flex.movie/acoolive 等)有条目但源不稳定、经常要 VIP

## Pitfalls
- **pkill 用 `pkill -x <binary>` 或精确模式**:`pkill -f 'aria2c.*HASH'` 会匹配到自己的 shell 命令行,把自己 SIGTERM 掉(exit -15)
- **老种子不一定死**:同片多个压制版,一个 0B/0B 拿不到元数据不代表全死(2016 Condo 死,BATV 活)。死种判断:连上 peer(CN>0)但 DL 一直 0B,等 2 分钟没起色就换下一个版本
- 磁力冷启动要时间:刚加 tracker 时 CN 会先上来又掉下去,正常
- 版权:这些资源都是民间压制/盗版,只做自用,别传播
- 中文字幕对冷门片极难找;英文 srt 常见。用户可接受"英文凑合"时先交付英文
