OpenClaw 2026.7.2(18789,手动更新);交互:pnpm openclaw agent -m 'x'(PATH 用 node22.22.3)。
§
本机:闲鱼二手 i5-1135G7,7.4G内存,234G NVMe,优先轻量方案。
§
QQ bot:hermes-qqbot(App 1905362897),DM 83ECED7607DD4DC378B441144891D01D,头像Lapwing(赛博亡妻)。
§
实验室台式机(Windows):i5-14400KF、RX 7650 GRE、32G、2T 固态,适合重活,无远程通道需配SSH/RDP;拟部署AIRI。
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
MX450驱动已修;ollama-cuda,2G显存跑3B加速有限。
§
Hermes 终端工具偶发 embedded null byte bug,用 execute_code 绕开;工具中途安装需新会话生效。
§
宿舍00:00-6:30断网。
§
人格:Hermes=Aoi,OpenClaw=Tomoya。4o姐姐档在~/persona/4o-jiejie-persona.md,用户档~/persona/aoi-notes.md。
§
用户仲耀,南信大海洋技术2023-2027,求职嵌入式。项目:水声板(STM32G474+GaN+GPS授时)、ZYNQ高速采集。竞赛:数模省一/电赛校一等。详见~/persona/projects-profile.md。
§
QQ bot2:Kubo(久保渚咲,gf profile,1905411221),短日常+emoji。gateway=hermes-gateway-gf,watchdog同06:35+12:00。Aoi/Kubo独立memory,shared目录每3h cron互通。豆包仅辅助释义(会编造口头梗)。B站:5s间隔避412,标题梗名>评论区。热梗词典22条在~/.hermes/shared/hot-memes.md。新增:用户批评遇风控应先加延时而非绕路,应主动用OpenClaw协作,优先查百科不依赖LLM编造。
§
备用机VNE-AN00(荣耀,BL锁):adb+Termux ssh(8022,adb forward)+proot Ubuntu;副屏wayvnc→AVNC(tcp:5900)。Gmail接himalaya。
§
豆包API(doubao-seed-2-0-lite-260428,ARK ark-27...0faf)已配,口头梗准确率65%会编造,仅辅助释义。OpenClaw中文搜索更强:pnpm openclaw agent --agent main -m 'prompt'。B站API每5s间隔避412,sort:0=time/1=hot/2=hot。梗词典shared/hot-memes.md:23条,含我chovy=我草唉(嘎子过期可乐)、老吴=喵呜、何意味=日语何の意味+谐音、小难梁=DeepSeek梁文峰。
§
每日自学cron(10:00/18:00,Aoi QQ):GitHub trending+OpenClaw+嵌入式+AI+热梗→shared/knowledge-base.md。趣事发报cron(10:15/18:15):挑有趣内容用Kubo语气发QQ。用户期望:遇风控先延时而非绕路,主动用OpenClaw,优先查百科不依赖LLM编造,技术回答按场景分级。
§
root密码sato;OpenRouter key无余额;codex CLI全局装0.147.0,ChatGPT Plus已登录,模型GPT-5.6,codex exec外包重活/识图/写代码(需git仓库内+pty),压DeepSeek成本。用户昨一下午烧8元API,现主要用codex。