# 中文互联网热梗追踪方案（2026-08-12 更新 v2）

## 核心教训

**B站 API 412 的唯一正确应对：加延时，不要换网站。**

错误路径：curl通→412→百度→验证码→搜狗→被拦→萌娘百科→绕一圈
正确路径：curl通→412→`sleep 5`→再试→通了 ✓

这个教训来自用户直接批评：慢速模拟真人访问是第一反应，不是最后手段。

## 已验证可用的方法

### B站搜索 + 慢速 API（可自动化 ✅）

```bash
# 步骤1：浏览器搜索（推荐用 browser 工具，自带反检测）
# 访问 https://search.bilibili.com/all?keyword=热梗&order=click
# 推荐 UP：梗百科（12.9亿播放）、江湖百晓生呀

# 步骤2：提取视频 aid，从标题直接拿梗名

# 步骤3：慢速 API 获取详情（≥5s 间隔，带 UA）
sleep 5 && curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://api.bilibili.com/x/web-interface/view?aid=<aid>"

# 步骤4：慢速 API 获取评论区
sleep 5 && curl -s -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
  "https://api.bilibili.com/x/v2/reply?type=1&oid=<aid>&pn=1&sort=2"
```

**关键原则**：
- 每个 API 调用 ≥5 秒间隔，像真人一样慢慢浏览
- 浏览器内 fetch 调用 B站 API 同样被拦截——用终端 curl 慢慢来
- 412 出现立即停止，增加延时后再试
- 视频标题是最高的梗名来源（合集视频标题直接列梗），评论区辅助

### 2026-09-14 实测补充（v3）

**接口层面的坑与正解**：

- `ranking/v2`（B站热榜）**裸 curl 首抓必被 `-352` 风控**，只带 UA 不够。
  正解：先 `curl -c cookie.txt https://www.bilibili.com/` 拿 cookie，之后所有 API 都带
  `-b cookie.txt -c cookie.txt` + `Referer: https://www.bilibili.com/`，每步 sleep 5~6s → 直接成功。
- **实时热搜词接口**（比热榜更贴"此刻在火什么"，一次 30 条）：
  `https://s.search.bilibili.com/main/hotword?limit=30`
- 搜索接口可直接用，`order=click`（按播放）和 `order=pubdate`（按最新）都好用：
  `https://api.bilibili.com/x/web-interface/search/type?search_type=video&order=pubdate&keyword=<urlencode>`
  → **`order=pubdate` + 关键词 "是什么梗" / "梗百科" / "盘点近期网络热梗" 是发现新梗的最快路径**，
  这类合集的标题直接把梗名写出来（如"盘点近期网络热梗：我从海底出击、高考固定NPC、雷霆动物集体蹦迪"）。

**评论区和简介基本没用**：合集视频的简介多为空，热评是"别打开""点赞的都是爷们"这类刷屏，
不要指望从评论区拿到释义，**直接跳到下一步交叉验证**。

**交叉验证源（比豆包强得多，优先用）**：

- `web_search` 工具在中文梗查询上**可用**（部分查询 30s 超时属正常，换措辞重试）。
- 高产的聚合榜单：数英《2026上半年网络热词TOP30》、hsk.cn-trending 2026梗词表、
  新浪/游侠/ali213 单梗解析、10100《22 Chinese Internet Slang Terms 2026》、gengbk.cn（梗捕快）。
- 判据：一个梗若同时出现在 **B站近两周合集标题 + 任一聚合榜单/媒体解析**，即可信度足够入词。
- 出处有分歧时（如"我要验牌"），采信媒体考据版并标注存疑，不要自己编。

### 豆包 API（仅润色，不发现）

doubao-seed-2-0-lite-260428，¥3/百万输入 token。

**三档模型实测**：lite/pro/turbo 对"我chovy"三种模型编出三种不同假答案。
- 适合：润色用户已确认梗的释义
- 不适合：自主发现新梗。口头谐音梗（我chovy/老吴/耄耋）= 全编

### 用户投喂（最准）

用户刷到新梗 → 告诉 Aoi → 写入词典。无延迟、无误判。

## 完整流程

1. 浏览器搜 B站 → 从热梗合集标题提取候选梗名
2. 慢速 API 拉视频简介和评论区 → 补充用法
3. 豆包辅助写释义 → 用户审核 → 写入 hot-memes.md
4. 同步到 ~/.hermes/shared/hot-memes.md（两个 profile 共享）
