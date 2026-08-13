# Extraction Recipes (2026-08 实测可用)

统一抓取函数(curl + 浏览器 UA,`--compressed` 解 gzip):
```python
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
def fetch(url, timeout=25):
    r = subprocess.run(["curl","-sL","--compressed","-A",UA,"--max-time",str(timeout),url],
                       capture_output=True, text=True, timeout=timeout+10)
    return r.stdout

def strip_tags(s):
    s = re.sub(r'<script.*?</script>|<style.*?</style>', ' ', s, flags=re.S)
    s = re.sub(r'<[^>]+>', ' ', s); s = html.unescape(s)
    return re.sub(r'\s+', ' ', s).strip()
```

## GitHub Trending
```python
page = fetch("https://github.com/trending?since=daily")
repos = re.findall(r'href="/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"', page)
descs = re.findall(r'<p class="col-9[^"]*">\s*(.*?)\s*</p>', page, flags=re.S)
# 过滤:跳过 repos 以 "sponsors/" 或 "apps/" 开头的广告位;去重;每条 sleep 3
```

## Hacker News
```python
ids = json.loads(fetch("https://hacker-news.firebaseio.com/v0/topstories.json"))[:6]
for hid in ids:
    item = json.loads(fetch(f"https://hacker-news.firebaseio.com/v0/item/{hid}.json"))
    # 字段: title, score, url; 每条间隔 sleep 2
```

## Phoronix(用 RSS,别用 HTML)
```python
rss = fetch("https://www.phoronix.com/rss.php")
items = re.findall(r'<title>(.*?)</title>', rss, flags=re.S)
# 跳过含 "Phoronix" 的站名条目,取前3
```
HTML 页面的 h2 正则解析实测失败,别浪费时间。

## 21IC
```python
t1 = re.findall(r'<a[^>]+title="([^"]{8,60})"', c)
t2 = re.findall(r'<h[23][^>]*>\s*<a[^>]*>(.*?)</a>', c, flags=re.S)
# 合并去重;注意首页混着大量旧专题(2023 测评合集),只留当日新鲜内容
```

## ddgs 搜索词(实测有效)
- AI 模型发布: `"DeepSeek V4 Pro 0813 发布"`、`"Qwen3.8 2.4T 千问 发布"` → 中文科技媒体结果很全
- 存储涨价: `"DRAM 内存 涨价 HBM 2026年8月 存储"` → TrendForce/美光/三星 HBM 新闻
  - `"MLCC涨价 OR STM32涨价 OR 芯片缺货 2026年8月"` → 结果多为旧闻,优先级低

## Bilibili 热梗(浏览器流程,替代易风控的 API)
1. `browser_navigate https://search.bilibili.com/all?keyword=<URL编码关键词>`
2. **必须点"最新发布"按钮**——默认 order=click 全是 2023-2025 年度盘点老视频,找不到新梗
3. 从结果 headings 收集候选梗名;每个候选重新搜索(输入框换词 + Enter)
4. 确认标准:梗名在**多个独立 UP 主的视频**交叉出现 + 有"梗指南/网梗解析"类视频 = ✅确认;只在盘点标题出现 = ❓
5. 佐证:看衍生玩梗方向(如"野生狗奶"→"人类害怕时间,而时间害怕野生狗奶"、BGM《吹梦到西洲DJ》)和来源线索(如粤西特供三无饮品)
6. API `x/web-interface/search/type` 部分关键词返回 HTML 而非 JSON(风控)→ 直接放弃 API 换浏览器,不要重试
