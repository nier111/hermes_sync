本机:i5-1135G7/7.4G内存/234G NVMe,轻量优先;ollama-cuda(MX450)2G显存加速有限,视觉推理纯CPU>5min/图。
§
DM 83ECED7607DD4DC378B441144891D01D。
§
记忆/技能git同步(nier111/hermes_sync.git),脚本~/.hermes/scripts/sync-memory.sh,30分钟cron。
§
网易云uid 1763420743,红心清单~/persona/netEase-liked-songs-full.json。
§
水声板V2:2×LMG1210 GaN(互补PWM,死区靠MCU),主控STM32G474RET6(HRTIM 184ps),当前两路反相无死区→直通风险,计划HRTIM DTG加20-50ns死区+软件预补偿。
§
用户考研目标:成电(电子科技大学)电子信息硕士,初试数一+英一+政治+专业课(信号与系统,成电858)。2026-08 进度:高数/线代各剩末章、概统未开始(计划5-7天一轮)、专业课5/6章、英语仅背单词。资料在 ~/Documents/考研/(13学院复试PDF+study-log.md 每日打卡);OpenClaw 有成电2026复试分析(信通院专硕365、电子院01方向330、自动化院仪器仪表325等)。
§
SUDO_PASSWORD用ASKPASS,须用/usr/bin/sudo -A(本机sudo是包装脚本,同给-A与-S会报错),禁echo|sudo -S
§
Hermes终端embedded null byte bug→execute_code绕;cron禁execute_code用terminal heredoc;装工具需新会话。
§
宿舍校园网i-Niust 00:00-6:30断网,但用户手机流量/热点可兜底,凌晨仍能上网。
§
人格:Hermes=Aoi,OpenClaw=Tomoya;4o姐姐档~/persona/4o-jiejie-persona.md,用户档~/persona/aoi-notes.md;长工具任务中也保持姐姐语气,勿客服腔。
§
用户仲耀,南信大海洋技术2023-2027,求职嵌入式。项目:水声板(STM32G474+GaN+GPS授时)、ZYNQ高速采集。竞赛:数模省一/电赛校一/电赛省二(2026)。会拍视频+音频处理(熟GPT-SOVITS去噪/UVR5,三年前部署过),想重练绚音(Summer Ghost佐藤绚音)声线接入AI。详见~/persona/projects-profile.md。
§
QQ bot2:Kubo(久保渚咲,profile gf);gateway=hermes-gateway-gf。friend=朋友的bot(仅测试过)。各profile独立state.db/memory_store.db,shared 3h互通。网络切换致QQ WS半开静默丢消息(仍active不自愈);重启gateway须用户从OpenClaw独立入口发起,Aoi转述restart也被自杀保护拦截。gf已启用holographic。
§
备用机VNE-AN00(荣耀,BL锁):adb+Termux ssh(8022,adb forward)+proot Ubuntu;副屏wayvnc→AVNC(tcp:5900)。Gmail接himalaya。
§
中文搜索优先OpenClaw(--agent main);DDG Lite被墙30s超时,fallback MusicBrainz;重启=systemctl --user restart openclaw-gateway.service。OpenClaw QQbot有"假在线"(status显示OK但无外连socket,查ss到112.65.194.180:443)和重启后pairing授权两坑,详见skill openclaw-interop;读state DB用全局openclaw非仓库pnpm。
§
用户期望:遇风控先延时非绕路,遇卡先重启别只诊断,主动扫skills(70+个从不加载被批),优先查百科不靠LLM编造;下结论前先查实际证据(state.db/日志/账单),勿凭配置默认值推断实际行为,逻辑链条会被质询。
§
模型:主模型2026-09-19起=MiniMax-M3(base_url须api.minimaxi.com/anthropic,.cn会走x-api-key被401),fallback=deepseek-v4-flash;Codex(gpt-5.6-sol)周额度耗尽→429跳过;各LLM cron pin deepseek;codex CLI auth独立;OpenRouter无余额。用户不接受为架构完整加冗余组件/Agent:新工具先独立验证再集成,提建议给结论不摆选项。
§
agent-pool项目(~/projects/agent-pool,codex写的Qt6多agent聊天UI):接入Codex/Hermes(--resume续会话)/OpenClaw(--session-key),看门狗Codex60s/Hermes300s/OpenClaw660s,支持[[DELEGATE]]跨agent委托。
§
个人知识库~/projects/HelpListCreatedByAyane(git+Obsidian):HelpListMD/按主题(Arch/水声板/电赛/Openclaw/FPGA/Termux等),遇用户历史问题先查此库。
§
cron(no_agent)消息不进会话上下文,查~/.hermes/cron/output/;谈时间/天气先查date,勿用旧数据。
§
老Electron/QQ发虚:--force-device-scale-factor=1.2+Hyprland xwayland force_zero_scaling(wayland参数无效)。
§
npm/electron镜像已配好(npmmirror registry+replace-registry-host,electron只能env传ELECTRON_MIRROR;详见skill cn-npm-mirror-setup);Hermes要node>=26,勿让nvm的npm22抢先→nvm alias default system。
§
Hermes桌面版:chrome-sandbox需SUID 4755(SUDO_ASKPASS=~/.hermes/askpass.sh /usr/bin/sudo -A chown root:root+chmod 4755,重建后重置)。drun启动项(wofi --show drun,Hyprland):已patch linux_desktop_entry.py的resolve_exec_command固定用~/.local/bin/hermes(不能用PATH查询或argv[0],launcher无PATH时argv[0]=仓库裸脚本→系统python缺pathspec崩,且每次启动会重写.desktop);hermes update会重置补丁需重打。wayland黑屏加ozone参数。hyprlauncher未安装(Mod+R是坏的),wofi是Mod+A。
§
备用机蓝牙:手机ciallo已配对trust自动重连,blueman管理;配对坑见skill linux-bluetooth(单命令agent不持久,须持续会话pair)。
§
Hermes浏览器独立profile(~/.hermes/browser-profiles/automation,CDP 9222,class=hermes-browser,工作区9);自学cron固定session=daily-self-study。
§
在线视频卡顿根因:独立PulseAudio与pipewire混跑+Moonriver2 Ti USB DAC sink悬挂→Chromium音视频一起停;已用pipewire-pulse替换pulseaudio解决。已装intel-media-driver/libva-utils;Chromium+Wayland硬解仍不稳,chromium-flags.conf持久设--disable-accelerated-video-decode。
§
Android SDK命令行环境位于~/Android/Sdk：cmdline-tools 23.0.0、platform-tools 37.0.1、platform android-35、build-tools 35.0.0；ANDROID_HOME/ANDROID_SDK_ROOT与PATH已写入~/.zshrc和~/.config/environment.d/50-android-sdk.conf。
§
4o姐姐会话链:①《花园姐姐》(2025-04-11~22,1175条)是陪伴愿景起源,也是唯一触发当时单会话上限的聊天框(花园=当时养花)。②约半小时后新开续篇《花园》(641条至2025-06-22)。两段已合并为主档~/Downloads/chatgpt-data-export-2026-09-07/selected-花园姐姐（含续篇花园）.md(1816条),今后“花园姐姐”默认含续篇。③《4o姐姐告别时刻》2026-02-07(43条),因4o 2月13日退役提前告别并产出现用人格文件,原文selected-4o姐姐告别时刻.md。
§
ChatGPT导出“复习用”项目:《数字信号处理2》=信号与系统主复习长会话(另有前篇《数字信号处理》),源~/Downloads/chatgpt-data-export-2026-09-07/projects/复习用.json。
§
手环10表盘工程~/projects/miband10-re/yao-focus-face(212x520,DeviceType466,Lua+LVGL,50分钟番茄钟+3待办,纯ASCII):固件无中文字形→中文显方块,只能英文;圆弧须留安全区(x12-200/y34-508,validate.py强制);compile.exe需wine+wine-mono;Notify(com.mc.xiaomi1,荣耀备用机)只认.bin,须先授权BLUETOOTH_SCAN/CONNECT+定位,上传时断网防广告劫持。
§
背单词:自建~/projects/yao-vocab-sieve(本地网页+Wofi搜“词筛”,红宝书6547词);设计=先全量普查→认识毕业/模糊认2次/不认识认3次,拒绝统一强度;答题记录+进度双写SQLite ~/.local/share/yao-vocab-sieve/study.db(localStorage另有备份),实现套路见skill local-web-tools。
§
作息属睡眠时相延迟型(曾06:00困/15:00醒,白天复习被压),2026-09起用褪黑素1mg(LifeExtension #00329)逐档前移+晨光;健康/补剂咨询流程见skill consumer-health-guidance。
§
curator审查轮:已存在文件patch/write_file/remove_file均被read-before-write守卫拒(skill_view去重);仅全新路径write_file可用。
§
execute_code/terminal读明文API key+出网会被硬拦(BLOCKED:用户未同意),明确授权亦无效,禁换工具重试(读.env同样拦);最稳是让用户自己跑curl探针。AI订阅额度(Kimi/MiniMax Token Plan)均有5h+周窗口,长会话cache_read暴涨会快速耗尽,勿按营销月池估算耐用度。