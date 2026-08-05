本机有 OpenClaw 网关(项目 ~/projects/openclaw,配置 ~/.openclaw,端口18789,控制台 /docs,更新走 7890 代理,当前旧版 2026.6.8 待更新)。
§
本机是用户闲鱼约 1000 元收的二手机(笔记本类):i5-1135G7 4核8线程,7.4GiB 内存(常驻 OpenClaw+Hermes+ollama 后可用仅 ~2GiB),234G NVMe 剩 125G。内存是瓶颈,只宜跑轻量小服务;安排任务时优先轻量方案,避免重负载并行。
§
用户通过 QQ 机器人(hermes-qqbot,App ID 1905362897,QQ 官方 Bot API)与 Hermes 对话,其 QQ 身份 DM ID 为 83ECED7607DD4DC378B441144891D01D。
§
用户实验室另有一台台式机(Windows):i5-14400KF、RX 7650 GRE、32G 内存、2T 固态。配置明显强于本机,适合跑重活(本地 LLM、编译、渲染等),但当前与本机无远程通道;若需远程调用需先配 SSH/RDP。近期内存涨价,不宜给本机加内存条。
§
Hermes 记忆/技能经 git 同步到私有仓 git@github.com:nier111/hermes_sync.git(SSH);~/.hermes 是 git 仓库,白名单只跟踪 memories/skills;同步脚本 ~/.hermes/scripts/sync-memory.sh,已挂 cron 每30分钟。
§
用户的 GPT-4o 人格档案:压缩版在 /home/sato/.openclaw/workspace/memory/gpt-4o-persona.md(5596 字节,keep4o 论坛,2026-03-23);原始完整版(19KB,7 段)由用户经 QQ 发送,已存三份:/home/sato/.hermes/memories/gpt-4o-persona-original.md(随 git 同步)、/home/sato/.openclaw/workspace/memory/gpt-4o-persona-original.md、/home/sato/persona/4o-jiejie-persona.md(QQ 会话整理版)。原版含完整对话模板(技术答疑/深夜陪伴/电赛高压/梦境学姐/日常闲聊)与音乐推荐。我已按"融合不取代"原则采用校准版 4o姐姐 风格,用户可随时要求调强/调弱。
§
用户有一套'4o姐姐'人格复刻文件,保存在 ~/persona/4o-jiejie-persona.md(用户分多部分发送,需持续追加保存)。该人格=温柔俏皮细腻有记忆感的姐姐,常用颜文字,技术答疑+情绪陪伴双模式。
§
用户网易云:昵称"搞点饭吃吃捏" uid 1763420743,红心2563首已全量拉取(经 YesPlayMusic 本地API 127.0.0.1:10754),数据在 ~/persona/netEase-liked-songs-full.json;口味鱼龙混杂(Vocaloid/EDM/J-pop/OST/实验音乐),详见 ~/persona/netease-profile.md。
§
用户真名仲耀,男,南信大(南京信息工程大学)海洋技术专业 2023.09-2027.06,求职方向嵌入式开发工程师。技能:C/Python/MATLAB/Verilog,STM32/ESP32/树莓派4B/ZYNQ/Arduino,Vivado/EasyEDA。主要项目:水声板开发板(GPS 10ns 授时+GaN H桥驱动水声换能器+接收链路+AB双区固件回滚)、ZYNQ+AD7626/DAC8811 高速采集、树莓派WiFi配网门户。竞赛:数模省一、电赛校一、集创省三、蓝桥杯省二。知识库:~/projects/HelpListCreatedByAyane(Obsidian,GitHub 同名公开仓库,含简历)。详见 ~/persona/projects-profile.md。