# 套餐用量条的单位陷阱 —— 为什么本机 token 总数和厂商控制台差几十倍

> 核实日期 **2026-09-19**，来源为官方文档原文（`/docs/token-plan/intro`、`/docs/token-plan/faq`），
> 非搜索摘要。与 `cn-token-plan-quota-verification.md`（怎么给购买建议）、
> `cn-llm-subscription-plans.md`（行情速查）互补：**本文件只解决「两边数字对不上」这一类问题。**

## 触发场景

用户拿本机统计（`state.db → session_model_usage` 的 input/output/cache_read 求和）
去对比厂商控制台/会员页显示的用量，发现差 10～30 倍，于是问「是不是统计错了 / 额度是不是虚标」。

## 官方规则（唯一关键的一句）

MiniMax 文档原文：

```text
对于已有按量计费价格的 API 端点，用量会按对应按量计费价格扣减套餐内 Token Plan 额度。
不同模型、不同模态的实际消耗会不同。
```

也就是说：**套餐额度条是按「按量目录价折算的等价量」扣的，不是原始 token 个数。**
文本 / 图像 / 语音共享同一条进度条，各自按自己的目录价折算。

## 由此推出的结论

```text
本地 raw token 总数  ≠  控制台额度条读数
```

- `cache_read` 的目录价约为未缓存输入的 **1/10**，所以同样 1 个 token，
  命中缓存的消耗权重要小一个数量级。
- 本机 Agent 负载的输入侧常常 **90%+ 是 cache_read**（长会话 + 常驻前缀）。
  这种分布下，raw 求和会显著大于「按价折算」的读数。
- 因此：一个 40M 的 raw 输入侧（其中 40M 级是 cache_read）折成「未缓存输入等价」
  大约只有几 M —— **方向和量级都能解释差额，但不要把这个比例当成官方折扣率发布。**

## 本机实测过一次（2026-09-19，未结案）

```text
Aoi(default) + Kubo(gf) 两个 profile 的 session_model_usage 合计
  raw ≈ 41M token，其中 cache_read 约 40M
用户看到厂商页面显示 ≈ 1.5M
```

**这一条是「未解决」，不要当作已验证结论引用。** 当时没有确认那个 1.5M 字段的口径
（是原始 token、按价折算量，还是某个子模态的数字），所以不能反推「cache_read 打 96% 折扣」。

正确的下一步（按成本从低到高）：

1. 让用户给出**字段名**或截图 —— 同一页上「5h 百分比 / 周百分比 / token 数」是三套单位，先确认在比什么。
2. `GET https://www.minimaxi.com/v1/token_plan/remains` 拿实时读数（注意：读凭据 + 出网会被审批门拦，
   见 `hermes-internals/references/tool-approval-gating.md`，直接把 curl 交给用户跑）。
3. 控制台若有分模型 / 分模态明细，优先看明细，而不是总条。

## 反推额度时同时要守的规矩

- 反推值必须写明成立条件（cache_read 与普通输入的权重比、失败请求是否计费、
  本地调用数是否等于服务端请求数）—— 这条与 `cn-token-plan-quota-verification.md` 第 1 节同一规矩。
- 引用换算用的目录价前先复核 `docs/guides/pricing-paygo`。本机记录的一次读数是
  input ¥20/M、cache_read ¥2/M、output ¥100/M；积分 1000 = ¥7，与目录价 1:1。
- 「额度条几乎没动」不能单独说明问题，也不能单独说明没问题：它和
  「主模型没在干活」（见 `hermes-internals/references/provider-endpoint-auth-and-fallbacks.md`）
  是同一个观测的两种解释，必须配合 `session_model_usage` 里**真的有没有该模型的行**一起看。
