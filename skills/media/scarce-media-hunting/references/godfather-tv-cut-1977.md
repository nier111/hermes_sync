# 实战案例:教父 1977 电视剧重剪版(七小时版)

用户目标:"The Godfather 的七小时电视剧重剪版"。2026-08 完整流程记录。

## 版本识别(先做,否则全错)
- **1977 NBC 版《The Godfather: A Novel for Television》**(又名 The Godfather Saga / 教父电视剧重剪版 / 教父传奇)
  - 434min(豆瓣写"4集共423分钟"),教父 1+2 按时间线重剪 + 补删减镜头,分 4 晚播出
  - 豆瓣条目:movie.douban.com/subject/4120658(片长字段 105min/集)
  - 从未出过官方蓝光/正版流媒体
- **2021 Paramount+ 版《Mario Puzo's The Godfather: The Complete Novel for Television》**
  - ~386min(6h26m),科波拉重新监督的重剪,加约 1 小时修复素材
  - 流媒体已下架(JustWatch US 显示不可播放)
- 中文网盘里搜"教父1-3"几乎全是剧场版,不是重剪版

## 搜索命中
- ddgs(带 http://127.0.0.1:7890 代理,覆盖全部 proxy 环境变量):
  - "教父 电视剧剪辑版 1977 A Novel for Television 7小时" → 豆瓣/letterboxd/实体碟
  - "The Godfather A Novel for Television 1977 blu-ray" → bddvdx(盗版 BD $22.99)、eBay
  - site:bilibili.com → 有 11 分钟片段(BV1cFwpeFE9R),非完整
  - rutracker t=6170394(俄站 "Эпос 1901-1959" Extended Complete Epic,需注册,Cloudflare 挡 curl)

## BT 下载结果
- 两个磁力:
  - Condo x265 720p(btih:27048C716382E99A61E6C32851532E5036E8EA1B):死种,连上 3 peer 拿不到元数据
  - **BATV[ettv] 720p HDTV x264(btih:4EB227AB5496DACB57BA8E1437BE7CD666CA71D8):活**,15.6G 单文件 mkv
- 下载:aria2 + ngosang trackerslist(20 个 tracker),unset all_proxy
- 速度从 500KiB 爬升到 8MiB/s,37 分钟下完 15.6G
- ffprobe 验证:1280x720 h264 23.976fps,AC3,25392s = 7h03m12s(423min,与豆瓣一致)

## 字幕获取(踩坑记录)
- subtitlecat.com 同名 BATV 字幕:只有 22 分钟(科波拉幕后访谈),不是正片 —— 必须 tail 验证时间轴
- opensubtitles.org:Anubis PoW 反爬;dl.opensubtitles.org 返回"Subtitle id not found"(ID 已删)
- azsubtitles:Cloudflare "Just a moment";Wayback 无快照
- assrt.net:搜索命中"中英简体 BATV 字幕",但详情页报 java.money.noMoneyException(要金币)
- **subdl.com 成功**:https://subdl.com/subtitle/sd14415/the-godfather-epic 页面 6 个 dl.subdl.com zip 全下载:
  - 372496-1294956(269KB,文件名 BATV 但内容是芬兰语!)← 语言陷阱
  - 372499-1276305(245KB,BATV[ettv] 英文正片,3281 条,尾时间码 06:58:40 ✓)
  - 372495-1490510(4.9KB,Non-English 意语段字幕,只标 "Speaking Sicilian" 不翻译)
  - 372494-1456295(The Complete Epic 1901-1959 版字幕)
- 交付:英文字幕与 mkv 同名同目录,播放器自动加载;中文字幕冷门片没有,用户接受英文

## 在线播放验证
- JustWatch US 搜索页(curl 可抓):两个版本均显示 "not available for streaming"
- ok.ru/video/9110896775545:完整 7:03:12,俄语标题,yt-dlp 报 "Unable to extract player params"
- Pluto TV:2024-10 限时播过,已过季
- 用户最终在 Telegram 群找到带中字的 4 集 720p 版(~10G),本机 15.6G 版留作收藏
