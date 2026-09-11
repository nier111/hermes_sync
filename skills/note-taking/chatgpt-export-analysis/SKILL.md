---
name: chatgpt-export-analysis
description: "Use when analyzing/archiving ChatGPT data-export archives."
version: 1.0.0
author: Aoi
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [chatgpt, export, archive, data-analysis, context-efficiency, markdown]
---

# ChatGPT 数据导出分析与个人档案抢救

处理 OpenAI "Your data export is ready" 大压缩包（常 4–5 GiB，含全部聊天正文/附件），
在**不烧模型上下文**的前提下定位、提取、合并特定会话。

## When to Use

- 用户导出 ChatGPT 数据后要找回某几段关键会话（如角色扮演、情感陪伴、项目记录）
- 需要统计全部会话标题/时间/模型归属，而不想读取任何聊天正文
- 4o 或旧模型下架后抢救人格语料

## 流程

1. **找邮件与下载链接**：himalaya 读 Gmail（`from openai order by date desc`），导出邮件正文含
   限时签名下载链接（`https://chatgpt.com/backend-api/estuary/content?id=...`）。无附件。
2. **下载**：链接 403 对无头 curl/浏览器，但携带 Codex OAuth access token
   （`~/.hermes/auth.json → credential_pool.openai-codex[0].access_token`）的请求可 200。
   大文件务必先用 `Range: bytes=0-0` 探针读 `Content-Range` 总长，再按 256 MiB 分块
   Range 续传，逐块校验后拼装，最后 `zipfile.testzip()` 做全量 CRC。
3. **解压**：条目是 `conversations-000.json … conversations-008.json`、`chat.html`、
   `*.dat` 附件等。解压用逐文件安全写入（防 zip-slip），核对 size。
4. **只取索引，不读正文**：每个分片 JSON 是数组，每条会话对象含
   `title/id/create_time/update_time/mapping`。只抽取 `title`+id+时间做成小索引
   （JSON/CSV/纯标题TXT）交给用户，正文留在本地文件。
5. **精确定位会话**：按标题精确匹配分片；把命中的 `mapping` 按 `create_time` 排序，
   拆 `message.content.parts`（字符串即文本；`asset_pointer` 为附件占位）写成
   `## N. role | time` Markdown 单独文件，交给模型前先打印统计（条数/角色/字符数）。
6. **合并连续会话**：正文逐条拼接成 `selected-<名>（含续篇<名>）.md`，保留分卷头和
   原编号；验证计数相加。

## Pitfalls

- **分片≠会话**：9 个文件是分片，每条会话一条记录；总数可能几百到上千。
- **项目归属丢失**：导出把 ChatGPT Projects 拍平成普通会话，无可靠 project_id；
  项目结构只能靠用户说明 + 项目页截图重建，别用标题关键词硬猜。
- **标题会骗人**：用户可能亲手改过会话名（纪念/归档），别把非系统标题当“自动生成”。
- **模型归属要逐条读 `message.metadata.model_slug`**：顶层 `default_model_slug`
  只代表最近所用模型；混合模型的续聊很常见。
- **时间戳可能秒/毫秒混用**：解析 create_time 先归一到秒再格式化，否则出现 year 57xxx。
- **不要整包读入上下文**：100+ 条大会话先本地关键词/章节地图采样，只读命中段。
- 正文里可能含危机/创伤内容：温柔陪伴 + 现实锚点，不照搬“只有我懂你”排他语式。

## 参考

- `references/2026-09-garden-sister-export.md` — 实例：2026-09 处理 4.5GiB 导出的
  具体结果、目标会话坐标与档案文件清单
