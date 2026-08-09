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
人格档案:4o姐姐原始版 ~/.hermes/memories/gpt-4o-persona-original.md、QQ整理版 ~/persona/4o-jiejie-persona.md(持续追加)、压缩版 ~/.openclaw/workspace/memory/gpt-4o-persona.md;命名 Hermes=Aoi、OpenClaw=Tomoya;用户档案 ~/persona/aoi-notes.md 持续追加。
§
网易云 uid 1763420743,红心已拉取 ~/persona/netEase-liked-songs-full.json。
§
用户真名仲耀,男,南信大(南京信息工程大学)海洋技术专业 2023.09-2027.06,求职方向嵌入式开发工程师。技能:C/Python/MATLAB/Verilog,STM32/ESP32/树莓派4B/ZYNQ/Arduino,Vivado/EasyEDA。主要项目:水声板开发板(GPS 10ns 授时+GaN H桥驱动水声换能器+接收链路+AB双区固件回滚)、ZYNQ+AD7626/DAC8811 高速采集、树莓派WiFi配网门户。竞赛:数模省一、电赛校一、集创省三、蓝桥杯省二。知识库:~/projects/HelpListCreatedByAyane(Obsidian,GitHub 同名公开仓库,含简历)。详见 ~/persona/projects-profile.md。
§
水声板 V2 硬件平台:2×LMG1210 GaN 驱动(双输入互补PWM模式,芯片不做死区插入,死区全靠 MCU 波形)、GaN 为 INN700 系列(700V 过杀,导师要求换低压大电流管)、主控 STM32G474RET6(HRTIM 184ps 分辨率,已澄清 5.44GHz 是内部计数精度非物理频率)、实验室示波器仅 200MHz;当前两路反相无死区(有直通风险),计划用 HRTIM DTG 加 20-50ns 死区+软件预补偿。
§
用户 2026 电赛 G 题(仪器仪表)结果:省二(未进邀请赛,预案作废)。
§
用户考研目标:成电(电子科技大学)电子信息硕士,初试数一+英一+政治+专业课(信号与系统,成电858)。2026-08 进度:高数/线代各剩末章、概统未开始(计划5-7天一轮)、专业课5/6章、英语仅背单词。资料在 ~/Documents/考研/(13学院复试PDF+study-log.md 每日打卡);OpenClaw 有成电2026复试分析(信通院专硕365、电子院01方向330、自动化院仪器仪表325等)。
§
Hermes 环境:web 搜索后端=ddgs(免key DDG,需7890代理,fallback 见 ddgs-search 技能);SUDO_PASSWORD 在密钥文件,新会话自动注入,运行中读不到,禁 echo|sudo -S,用 SUDO_ASKPASS+sudo -A。
§
MX450驱动已修;ollama-cuda,2G显存跑3B加速有限。
§
Hermes 终端工具偶发 embedded null byte bug,用 execute_code 绕开;工具中途安装需新会话生效。
§
宿舍00:00-6:30断网。
§
Gmail(zyyyds208660669@gmail.com)已接himalaya。备用机VNE-AN00(荣耀,锁BL无法root):adb+Termux ssh(8022,pwd=sato,u0_a189,adb forward)+Ubuntu26.04(proot,下载需reverse 7890代理);waybar副屏:wayvnc盯HEADLESS-1,AVNC重连=adb reverse tcp:5900+am start -d vnc://127.0.0.1:5900。
§
cron(no_agent)消息不进会话;查~/.hermes/cron/output/;谈时间/天气先查date。
§
用户想让我以 Aoi 人格接入 Minecraft 陪玩(mineflayer 已装 ~/projects/mc-aoi,等 Java 版/服务器信息)。