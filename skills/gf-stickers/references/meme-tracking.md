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
