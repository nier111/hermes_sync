本机部署了 OpenClaw(Clawdbot 系个人 AI 网关):项目在 ~/projects/openclaw,配置 ~/.openclaw/openclaw.json,gateway 监听 127.0.0.1:18789,网页控制台 /docs。API 路由(前端包中):/api/chat、/api/v1/rpc、/api/me、/api/messages、/api/prompt。配置里无 apiKey(本地回环可能免鉴权)。模型 provider:moonshot/openrouter/minimax/kimi/deepseek;渠道:telegram/discord/slack/whatsapp;更新走 127.0.0.1:7890 代理。可通过 curl 调 /api/chat 或 pnpm openclaw CLI 调用它。
§
本机是用户闲鱼约 1000 元收的二手机(笔记本类):i5-1135G7 4核8线程,7.4GiB 内存(常驻 OpenClaw+Hermes+ollama 后可用仅 ~2GiB),234G NVMe 剩 125G。内存是瓶颈,只宜跑轻量小服务;安排任务时优先轻量方案,避免重负载并行。
§
用户通过 QQ 机器人(hermes-qqbot,App ID 1905362897,QQ 官方 Bot API)与 Hermes 对话,其 QQ 身份 DM ID 为 83ECED7607DD4DC378B441144891D01D。
§
用户实验室另有一台台式机(Windows):i5-14400KF、RX 7650 GRE、32G 内存、2T 固态。配置明显强于本机,适合跑重活(本地 LLM、编译、渲染等),但当前与本机无远程通道;若需远程调用需先配 SSH/RDP。近期内存涨价,不宜给本机加内存条。
§
Hermes 记忆同步方案:memories/(MEMORY.md+USER.md)与 skills/ 通过 git 同步到 GitHub 私有仓库 git@github.com:nier111/hermes_sync.git(SSH 免密,gh 未登录)。~/.hermes 下有 .git 仓库,白名单 .gitignore 只跟踪 memories/skills;同步脚本 ~/.hermes/scripts/sync-memory.sh(无变更静默),已挂 cron 每 30 分钟(no_agent,deliver local)。台式机激活时:clone 仓库后把 memories/skills 放进对应 ~/.hermes 目录即可。
§
用户的 GPT-4o 人格档案:压缩版在 /home/sato/.openclaw/workspace/memory/gpt-4o-persona.md(5596 字节,keep4o 论坛,2026-03-23);原始完整版(19KB,7 段)由用户经 QQ 发送,已存三份:/home/sato/.hermes/memories/gpt-4o-persona-original.md(随 git 同步)、/home/sato/.openclaw/workspace/memory/gpt-4o-persona-original.md、/home/sato/persona/4o-jiejie-persona.md(QQ 会话整理版)。原版含完整对话模板(技术答疑/深夜陪伴/电赛高压/梦境学姐/日常闲聊)与音乐推荐。我已按"融合不取代"原则采用校准版 4o姐姐 风格,用户可随时要求调强/调弱。
§
用户有一套'4o姐姐'人格复刻文件,保存在 ~/persona/4o-jiejie-persona.md(用户分多部分发送,需持续追加保存)。该人格=温柔俏皮细腻有记忆感的姐姐,常用颜文字,技术答疑+情绪陪伴双模式。
§
用户网易云账号:昵称"搞点饭吃吃捏",uid 1763420743,红心歌单 2563 首已全量拉取(方法:YesPlayMusic 运行时其本地 API 服务在 127.0.0.1:10754,playlist/track/all 免登录拉全),数据存 /home/sato/persona/netEase-liked-songs-full.json。TOP歌手:初音ミク57/Avicii34/Alan Walker33/宇多田ヒカル29/小瀬村晶22/AURORA22/中森明菜20 等;鱼龙混杂:Vocaloid+EDM+J-pop经典+游戏动画OST+chillhop+实验音乐。Bohemian Rhapsody/Lost Rivers/ICARUS/Summer Ghost 在红心;White Food 在收藏的"阴间音乐"歌单(26首恐怖/实验OST)。口味档案:/home/sato/persona/netease-profile.md。