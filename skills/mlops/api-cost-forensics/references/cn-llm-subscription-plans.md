# 中文区 LLM 订阅 / token 套餐行情

> 核实日期 **2026-09-18**（官方页读全文，非搜索摘要）。
> 价格与规则会变 —— 引用本文件数字前先跑下面的「复核清单」抓最新值。

## Kimi（月之暗面）

官方页：
- 会员收费与套餐：https://www.kimi.com/zh-hans/help/membership/membership-pricing
- Kimi Code 会员权益（额度/窗口/加油包）：https://www.kimi.com/code/docs/kimi-code/membership.html
- Kimi Code 概览（API 接入、模型 ID、协议）：https://www.kimi.com/code/docs/
- 新版 Code 定价页：https://www.kimi.com/zh-cn/resources/kimi-k2-7-code-pricing

要点：
- 新档（年付月均）：Go ¥39 / Plus ¥79 / Pro ¥159 / Max ¥559；官网同时标原价 ¥49 / 99 / 199 / 699。
  老档名仍在使用：Andante ¥49 / Moderato ¥99 / Allegretto ¥199 / Allegro ¥699。
- **Kimi Code 门槛**：新档 Plus 及以上，老档 Andante 及以上；Go 档无 coding 额度。
- K3 调用门槛 Plus+；K3 的 1M 上下文与高速版需 Pro+（老档 Allegretto+）。
- **计费口径**：所有会员功能共享一个月度额度池，**按实际 token 消耗扣减**，不按请求次数。
- **窗口**：新会员取消周限额，保留 5 小时**滚动**频控；老会员保留「每 7 天刷新 + 5 小时滚动」。
- **超额续用**：加油包（Extra Usage），按用量计费、单价近似开放平台 API 价；订阅额度先扣、加油包兜底，可设月度消费上限。单次最低充 ¥25。
- 模型 ID：`k3` / `k3-256k` / `kimi-for-coding`(K2.8 Preview) / `kimi-for-coding-highspeed`；
  `k3` 的 1M 上下文消耗约为 `k3-256k` 的两倍 → 别默认全开 1M。
- API 同时兼容 OpenAI 与 Anthropic 协议：`https://api.kimi.com/coding/v1` / `https://api.kimi.com/coding/`（海外 `api.kimi.ai`）。
  官方警告：篡改客户端 User-Agent 视为违规，可能暂停会员权益。
- Kimi Code 会员权益与开放平台按量付费是两套体系（前者有频控，后按量充值即用）。
- 官方还有 Kimi Claw（云端 OpenClaw 沙箱）——**待机也按天扣约会员额度 0.6%**，不用就走「删除云主机」。

## MiniMax

官方页：
- Token Plan 定价：https://platform.minimaxi.com/docs/guides/pricing-token-plan
- 概要：https://platform.minimaxi.com/docs/token-plan/intro
- 常见问题（窗口/超额/限流）：https://platform.minimaxi.com/docs/coding-plan/faq
- 迁移说明（口径变更始末）：https://platform.minimaxi.com/docs/token-plan/migration
- Hermes 官方接入：https://platform.minimaxi.com/docs/token-plan/hermes-agent
- 按量计费目录价（换算积分用）：https://platform.minimaxi.com/docs/guides/pricing-paygo

要点：
- 档位：Plus ¥49（约 3-4 个 Agent）/ Max ¥119（4-5）/ Ultra ¥469（6-7，月容量约 71 亿 token，含每日 5 条视频）。
- 老保留档：Starter ¥29、Plus-极速 ¥98 —— 仅老用户可续，新用户已买不到。
- **计费口径已改**：M3 上线后从「5 小时 prompt 次数」切到 **Token-Based**，按各资源的按量目录价折算套餐额度。
  积分 1000 积分 = ¥7，与 API 目录价 1:1，无加价。
- **窗口**：5 小时**固定**窗口 + 周窗口 + 月度套餐池；未用完不结转。
- **超额**：已购积分自动补（1 年有效）→ 升级档位 → 换回普通按量 API Key → 等窗口重置。
- 订阅 Key 与按量 API Key **不能混用**。查用量：`GET https://www.minimaxi.com/v1/token_plan/remains` 或控制台「套餐用量」。
- **多模态**：M3 / M2.7 / 图像 / 语音共享同一额度池；
  **MiniMax H3 视频、音色设计、快速复刻不在 Token Plan 覆盖内** —— 「视频效果好」不能当作编程套餐的附赠。
- 限流：超 RPM/TPM 约 1 分钟恢复；高峰（工作日 15:00-17:30）动态收紧。
- 官方声明面向个人交互式使用，生产环境建议按量付费；订阅制不支持退款。
- 官方自己道歉过一次口径切换（未提前沟通 + 老用户周限额处理不当），migration 页写得比 pricing 页更诚实。

## 复核清单（每次重查都走一遍）

1. 开 **定价页 + FAQ + migration** 三页 —— 口径变更几乎都写在 migration 里。
2. 逐项确认：计费口径（token / 请求 / 积分折算）→ 窗口类型（滚动 vs 固定）→ 档位门槛
   → 超额续用方式 → 多模态是否共享、哪些模型被排除 → 目标工具有没有官方接入页。
3. 抓取方式：厂商文档站是 JS 渲染的 SPA。用 browser_exec 起多个 session 并行打开，
   `js("document.body.innerText")` 直接读渲染后全文；搜索摘要常把新旧口径混着说，不可信。
4. 别把「多模态/视频」权益默认当作低档套餐附带，也别把第三方对比站的数字当官方。

## 与本机使用方式的关系

用户负载特征：平时低频，但会突然进入**连续数小时的高强度 Agent 工作链**（逆向、调板、长工具循环）。
这种负载最怕「单次长任务吃掉大块额度」→ 按 token 计费时要先确认**单次任务成本**和**窗口恢复速度**，
而不是只算「每月多少次请求」。ChatGPT Plus 的 5 小时动态额度、MiniMax 的 5h+周窗口同理。
