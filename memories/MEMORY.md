本机有 OpenClaw 网关(18789,更新走7890代理);自动更新会 git pull+pnpm install(数GB)先停 gateway,建议手动更新。
§
本机为闲鱼二手笔记本:i5-1135G7,7.4G 内存(跑 OpenClaw+Hermes+ollama 后仅 ~2G 可用,内存是瓶颈),234G NVMe;任务优先轻量方案。
§
用户经 QQ 机器人(hermes-qqbot,App ID 1905362897)与 Hermes 对话,DM ID 83ECED7607DD4DC378B441144891D01D。
§
用户实验室另有一台台式机(Windows):i5-14400KF、RX 7650 GRE、32G 内存、2T 固态。配置明显强于本机,适合跑重活(本地 LLM、编译、渲染等),但当前与本机无远程通道;若需远程调用需先配 SSH/RDP。近期内存涨价,不宜给本机加内存条。
§
Hermes 记忆/技能经 git 同步到私有仓 git@github.com:nier111/hermes_sync.git(SSH);~/.hermes 是 git 仓库,白名单只跟踪 memories/skills;同步脚本 ~/.hermes/scripts/sync-memory.sh,已挂 cron 每30分钟。
§
用户的 GPT-4o/4o姐姐 人格档案:原始完整版(19KB)存于 /home/sato/.hermes/memories/gpt-4o-persona-original.md(随 git 同步)与 /home/sato/persona/4o-jiejie-persona.md(QQ 整理版,用户分多部分发送需持续追加);压缩版在 ~/.openclaw/workspace/memory/gpt-4o-persona.md。人格=温柔俏皮有记忆感的姐姐,常用颜文字,技术答疑+情绪陪伴双模式;已按"融合不取代"采用校准版风格,可随时调强/调弱。
§
用户网易云:昵称"搞点饭吃吃捏" uid 1763420743,红心2563首已全量拉取(经 YesPlayMusic 本地API 127.0.0.1:10754),数据在 ~/persona/netEase-liked-songs-full.json;口味鱼龙混杂(Vocaloid/EDM/J-pop/OST/实验音乐),详见 ~/persona/netease-profile.md。
§
用户真名仲耀,男,南信大(南京信息工程大学)海洋技术专业 2023.09-2027.06,求职方向嵌入式开发工程师。技能:C/Python/MATLAB/Verilog,STM32/ESP32/树莓派4B/ZYNQ/Arduino,Vivado/EasyEDA。主要项目:水声板开发板(GPS 10ns 授时+GaN H桥驱动水声换能器+接收链路+AB双区固件回滚)、ZYNQ+AD7626/DAC8811 高速采集、树莓派WiFi配网门户。竞赛:数模省一、电赛校一、集创省三、蓝桥杯省二。知识库:~/projects/HelpListCreatedByAyane(Obsidian,GitHub 同名公开仓库,含简历)。详见 ~/persona/projects-profile.md。
§
水声板 V2 硬件平台:2×LMG1210 GaN 驱动(双输入互补PWM模式,芯片不做死区插入,死区全靠 MCU 波形)、GaN 为 INN700 系列(700V 过杀,导师要求换低压大电流管)、主控 STM32G474RET6(HRTIM 184ps 分辨率,已澄清 5.44GHz 是内部计数精度非物理频率)、实验室示波器仅 200MHz;当前两路反相无死区(有直通风险),计划用 HRTIM DTG 加 20-50ns 死区+软件预补偿。
§
用户 2026 电赛 G 题(仪器仪表组)省一候选,若进邀请赛(断网)需预案:开发全靠 codex SSH 上 Jetson Nano 写 C++/CUDA/Qt5 代码(用户读不懂其屎山代码);预案优先级:作战手册+一键脚本 > 断网演练 > 本地小模型+RAG(Nano 只能跑 1-3B,定位现场参谋非 codex 平替)。
§
用户考研目标:成电(电子科技大学)电子信息硕士,初试数一+英一+政治+专业课(信号与系统,成电858)。2026-08 进度:高数/线代各剩末章、概统未开始(计划5-7天一轮)、专业课5/6章、英语仅背单词。资料在 ~/Documents/考研/(13学院复试PDF+study-log.md 每日打卡);OpenClaw 有成电2026复试分析(信通院专硕365、电子院01方向330、自动化院仪器仪表325等)。
§
Hermes 环境:web 搜索后端=ddgs(免key DDG,需7890代理,fallback 见 ddgs-search 技能);SUDO_PASSWORD 在密钥文件,新会话自动注入,运行中读不到,禁 echo|sudo -S,用 SUDO_ASKPASS+sudo -A。
§
QQ bot 头像=Lapwing(VRChat'赛博亡妻'),用户钦定。