本机部署了 OpenClaw(Clawdbot 系个人 AI 网关):项目在 ~/projects/openclaw,配置 ~/.openclaw/openclaw.json,gateway 监听 127.0.0.1:18789,网页控制台 /docs。API 路由(前端包中):/api/chat、/api/v1/rpc、/api/me、/api/messages、/api/prompt。配置里无 apiKey(本地回环可能免鉴权)。模型 provider:moonshot/openrouter/minimax/kimi/deepseek;渠道:telegram/discord/slack/whatsapp;更新走 127.0.0.1:7890 代理。可通过 curl 调 /api/chat 或 pnpm openclaw CLI 调用它。
§
本机是用户闲鱼约 1000 元收的二手机(笔记本类):i5-1135G7 4核8线程,7.4GiB 内存(常驻 OpenClaw+Hermes+ollama 后可用仅 ~2GiB),234G NVMe 剩 125G。内存是瓶颈,只宜跑轻量小服务;安排任务时优先轻量方案,避免重负载并行。
§
用户通过 QQ 机器人(hermes-qqbot,App ID 1905362897,QQ 官方 Bot API)与 Hermes 对话,其 QQ 身份 DM ID 为 83ECED7607DD4DC378B441144891D01D。
§
用户实验室另有一台台式机(Windows):i5-14400KF、RX 7650 GRE、32G 内存、2T 固态。配置明显强于本机,适合跑重活(本地 LLM、编译、渲染等),但当前与本机无远程通道;若需远程调用需先配 SSH/RDP。近期内存涨价,不宜给本机加内存条。
