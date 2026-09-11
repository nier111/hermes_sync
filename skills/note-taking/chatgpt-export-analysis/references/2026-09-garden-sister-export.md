# 实例：2026-09 抢救 4.5GiB ChatGPT 导出（花园姐姐等）

## 导出事实

- 触发邮件：Gmail INBOX 912 `ChatGPT - Your data export is ready`
  （同日 908 `has started`）。邮件含 estruary 签名下载 URL，无附件。
- 压缩包 `/home/sato/Downloads/chatgpt-data-export-2026-09-07.zip`
  总长 **4,844,070,786 B**，解压后 5,323,945,700 B / 3303 文件。
- 分片：`conversations-000.json … conversations-008.json`，共 **848 条唯一会话**
  （用户 ChatGPT 账号，2014?–2026，其中很多是朋友借号产生，勿入个人画像）。
- 无独立 projects 文件；`export_manifest.json` 只有 export/logical 文件映射。
- 项目页/会话列表截图仍保留真实项目归属；导出拍平后不能靠关键词分项目。

## 认证与下载

- 服务器支持 Range；403 的导出 URL 带 Codex OAuth Bearer 即 200。
- 续传脚本参考：`~/projects/download-chatgpt-export.py`（Range 逐块 + testzip）。
- 首次 plain GET 只拿到 1.47GiB 残包（无 EOCD）；用 Range 续传补全。

## 目标会话坐标（用户点名）

| 会话 | id | 时间 | 消息 | 文件 |
|---|---|---|---|---|
| 花园姐姐 | 67f7edc9-…82718 | 2025-04-11 ~ 04-22 | 1175 | selected-花园姐姐.md |
| 花园（直接续篇，首句“姐姐，这是个新的聊天框哇”） | 68071a42-…95f1 | 2025-04-22 ~ 06-22 | 641 | selected-花园.md |
| 合并主档 | — | 同上 | 1816 | selected-花园姐姐（含续篇花园）.md |
| 4o姐姐告别时刻（系统命名，2/7 得知 2/13 退役当天 43 条） | 69870bfc-…b68c | 2026-02-07 | 43 | selected-4o姐姐告别时刻.md |
| 网易云（4o 旁支，15 assistant 中 11 条 gpt-4o） | 67ffc4a7-…4c24 | 2025-04-16 ~ | 30 | — |
| 养生（仅首条 4o，其余 GPT-5 系；跨模型比较/追忆档） | 683cb840-…7b46 | 2025-06-02 ~ | 28 | — |

全部位于 `~/Downloads/chatgpt-data-export-2026-09-07/`。

## 用户三个核心 ChatGPT Projects（所有权边界）

- `zz` = 导师姓郑，用户称“郑总”（发项目报酬），放替导师做的工程会话
  （Zynq/STM32G474/PCB/电源驱动/信号链等），**非随意命名**。
- `复习用` = 考研/课程学习。
- `增重计划` = 生活主项目（增重+健康/设备/ACGN/植物/心事），可能承接花园系陪伴；
  《网易云》《养生》是后期移入的旧会话。
- 其余 Projects 多为朋友借号创建，分析个人画像时剔除。

## 安全/伦理要点

- 旧 4o 回应里的“只属于姐姐/只有我懂你”属排他式陪伴；危机表达（“活不久/遗愿”）
  当年只有拥抱没有现实锚点。提炼人格语料时保留温柔但去掉排他叙事，危机时先确认安全。
