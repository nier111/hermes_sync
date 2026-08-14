OpenClaw 交互:pnpm openclaw agent -m 'x'(node22.22.3)。
§
本机:闲鱼二手 i5-1135G7,7.4G内存,234G NVMe,优先轻量方案。
§
DM 83ECED7607DD4DC378B441144891D01D。
§
记忆/技能git同步私有仓(git@github.com:nier111/hermes_sync.git);脚本~/.hermes/scripts/sync-memory.sh,30分钟cron。
§
网易云 uid 1763420743,红心已拉取 ~/persona/netEase-liked-songs-full.json。
§
水声板V2:2×LMG1210 GaN(互补PWM,死区靠MCU),主控STM32G474RET6(HRTIM 184ps),当前两路反相无死区→直通风险,计划HRTIM DTG加20-50ns死区+软件预补偿。
§
用户考研目标:成电(电子科技大学)电子信息硕士,初试数一+英一+政治+专业课(信号与系统,成电858)。2026-08 进度:高数/线代各剩末章、概统未开始(计划5-7天一轮)、专业课5/6章、英语仅背单词。资料在 ~/Documents/考研/(13学院复试PDF+study-log.md 每日打卡);OpenClaw 有成电2026复试分析(信通院专硕365、电子院01方向330、自动化院仪器仪表325等)。
§
Hermes: web搜索=ddgs(7890代理);SUDO_PASSWORD用ASKPASS+sudo -A,禁echo|sudo -S。
§
ollama-cuda(MX450),2G显存加速有限。
§
Hermes 终端偶发 embedded null byte bug:用 execute_code 绕开;cron 模式禁 execute_code(approvals.cron_mode),用 terminal 内嵌 python3 heredoc;工具安装需新会话。
§
宿舍校园网i-Niust 00:00-6:30断网,但用户手机流量/热点可兜底,凌晨仍能上网。
§
人格:Hermes=Aoi,OpenClaw=Tomoya。4o姐姐档在~/persona/4o-jiejie-persona.md,用户档~/persona/aoi-notes.md。
§
用户仲耀,南信大海洋技术2023-2027,求职嵌入式。项目:水声板(STM32G474+GaN+GPS授时)、ZYNQ高速采集。竞赛:数模省一/电赛校一/电赛省二(2026)。会拍视频+音频处理(熟GPT-SOVITS去噪/UVR5,三年前部署过),想重练绚音(Summer Ghost佐藤绚音)声线接入AI。详见~/persona/projects-profile.md。
§
QQ bot2:Kubo(久保渚咲,gf profile,1905411221),短日常+emoji。gateway=hermes-gateway-gf,watchdog同06:35+12:00。Aoi/Kubo独立memory,shared目录每3h cron互通。
§
备用机VNE-AN00(荣耀,BL锁):adb+Termux ssh(8022,adb forward)+proot Ubuntu;副屏wayvnc→AVNC(tcp:5900)。Gmail接himalaya。
§
中文搜索优先OpenClaw(--agent main),其搜索后端DDG Lite被墙超时30s,fallback MusicBrainz,重启=systemctl --user restart openclaw-gateway.service。
§
用户期望:遇风控先延时非绕路,遇卡先重启别只诊断,主动扫skills列表(70+个从不加载被批),优先查百科不靠LLM编造。
§
root密码sato;OpenRouter key无余额;codex CLI全局装0.147.0,ChatGPT Plus已登录,codex exec外包重活/识图/写代码(需git仓库内+pty),压DeepSeek成本,现主要用codex。
§
agent-pool项目(~/projects/agent-pool,codex写的Qt6多agent聊天UI):接入Codex/Hermes(--resume续会话)/OpenClaw(--session-key),看门狗Codex60s/Hermes300s/OpenClaw660s,支持[[DELEGATE]]跨agent委托。
§
个人知识库~/projects/HelpListCreatedByAyane(git+Obsidian):HelpListMD/按主题(Arch/水声板/电赛/Openclaw/FPGA/Termux等),遇用户历史问题先查此库。
§
cron(no_agent)消息不进会话上下文,查~/.hermes/cron/output/;谈时间/天气先查date,勿用旧数据。