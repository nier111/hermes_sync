---
name: daily-knowledge-digest
description: "Use for the daily knowledge roundup cron (10:00/18:00)."
version: 1.0.0
---

# Daily Knowledge Digest (每日自学/知识库 cron)

Trigger: 每日 10:00/18:00 cron 或"浏览互联网获取新知、写入知识库、输出简报"类任务。结果投递为最终回复本身(cron 模式),不需要 send_message。

## 核心:抓取方式

**web_extract 在 ddgs 后端下不可用**(报 "search-only backend cannot extract URL content")——这是配置事实,不是临时故障。抓取一律用 terminal 内嵌 python3 heredoc + curl(`--compressed`,`-A` 浏览器 UA)。cron 模式禁 execute_code,必须 heredoc。现成可复用片段见 `references/extraction-recipes.md`。

## 来源清单与访问方式

1. **GitHub Trending**: curl HTML → 正则提取 repo href + `<p class="col-9...">` 描述。⚠️ 过滤 `sponsors/`、`apps/` 等广告位条目
2. **HN**: `https://hacker-news.firebaseio.com/v0/topstories.json` → 前5-6条 id → `/v0/item/{id}.json`(每条间隔 sleep 2)
3. **Phoronix**: HTML 正则易失败,直接用 RSS `https://www.phoronix.com/rss.php` → `<title>` 提取
4. **21IC**: `<a[^>]+title="...">` + h2/h3 链接,去重;内容多为旧专题,只取当日新鲜标题
5. **EET China**: HTML 抓取可能失败,失败就跳过,不影响其他源
6. **元器件/存储/AI 价格新闻**: ddgs web_search,关键词见 recipes
7. **B站热梗**: 走 browser(API 部分词会返回 HTML 风控页),用**最新发布**排序,详见 `bilibili-meme-discovery`
8. **OpenClaw**: `cd ~/projects/openclaw && timeout 40 git fetch origin main && git log --oneline -5 origin/main`

## 输出

1. 全部发现按日期追加写入 `~/.hermes/shared/knowledge-base.md`:`## YYYY-MM-DD (周X)` 标题 + 分类小节(每类小节头可带 emoji 图标)
2. 简报 ≤12 行,格式固定:
```
🐙 GitHub: 项目1 / 项目2
🦞 OpenClaw: 最新更新
🔌 嵌入式: 元器件价格、芯片供应
🤖 AI: 行业动态
💻 系统/硬件: Linux/硬件新闻
🔥 热梗: 候选梗
```
每类最多 2 条,无新内容就跳过该类;行数超限砍次要项。

## Pitfalls

- **web_extract 不可用是常态**(ddgs 后端搜索-only)→ 永远 curl+python3,不要每次重试 web_extract 浪费时间
- GitHub trending 前几项可能是 sponsors/ 广告,提取后要过滤
- B站搜索 API 部分关键词返回 HTML 而非 JSON = 风控,立即换浏览器,别重试 API
- B站 API 间隔必须 sleep 5+ 秒,否则 412
- 热梗判定:梗名必须在**多个独立视频交叉出现**才算确认;只在盘点标题里的短语(如"雷霆热梗")可能是标题风格,标 ❓ 不确认
- 存储/芯片涨价是高频话题,用"DRAM 内存 涨价 HBM 2026年8月 存储"类查询比"MLCC涨价"更出有效结果
- 简报里标注重要新闻来源置信度(✅确认 / ⚠️萌芽 / ❓未确认),并给一条对用户有价值的提醒(如新模型价格对比)
- 热梗入库 hot-memes.md 需用户判定,自动流程只写 knowledge-base.md

## 支持文件

- `references/extraction-recipes.md` — 各来源验证过的 curl+python3 解析片段与搜索词
