# Curl 抓取配方(web_extract 不可用/被 ddgs 后端拒绝时)

实测于 2026-08-13 每日知识库 cron。站点间 5s+ 间隔防限流。curl 管道 python3 会被安全扫描标记,但本机智能审批会自动放行。

## GitHub Trending
```bash
curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://github.com/trending?since=daily" -o /tmp/gh.html
```
- 仓库名/owner 正则(实测有效): `<h2 class="h3 lh-condensed">.*?href="/([^"]+)"[^>]*>(.*?)</a>`
- 描述正则 `<p class="col-9 color-fg-muted my-1 pr-4">` **实测抓不到**(HTML 结构与预期不符,勿复用)
- 可靠拿描述:逐个请求 `https://api.github.com/repos/{owner}/{repo}`(未认证限 60 次/时,取前 5 个够用);字段 `full_name` / `stargazers_count` / `description`

## Hacker News(直连可用)
```bash
curl -s "https://hacker-news.firebaseio.com/v0/topstories.json"   # 前 5 个 id
curl -s "https://hacker-news.firebaseio.com/v0/item/{id}.json"    # title / url / score
```

## 21IC(国内直连)
```bash
curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64)" "https://www.21ic.com/" -o /tmp/21ic.html
```
- 标题正则: `<a[^>]*title="([^"]{10,80})"[^>]*>`,去重后取前 15 条;TrendForce 专栏条目质量最高(存储/电池/芯片成本类)

## Phoronix
curl 会被 Cloudflare "Just a moment..." 挑战挡住(返回 ~5KB JS 壳页面)。**直接换浏览器工具**,别浪费时间重试。

## Bilibili API(配合用户自建 bilibili-meme-discovery 技能;该技能本人维护时需 `hermes curator adopt`)
- 搜索:`https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=<URL编码>`
  **必须带 `Referer: https://www.bilibili.com/`**,否则返回 HTML 风控页(JSON 解析报 `Expecting value`),不是 412、也不是 JSON
- 详情:`https://api.bilibili.com/x/web-interface/view?bvid={bvid}`(bvid 可直接用,不必先转 aid)
- 盘点视频(如"八月四大抽象热梗")描述经常为空 —— 梗名以标题为准,别指望描述给释义
- 找"当下"新梗:搜索页 order=click 默认全是年度总结旧梗,要点"最新发布"排序
