# 原理图/PCB 识图工作流（VLM）

## 结论：豆包 VLM 读原理图可靠，Codex(GPT-5.6) 更强

本会话验证：把水声板原理图 PDF（SCH_Schematic1_2026-06-20.pdf）转图后喂给
doubao-seed-2-0-lite-260428（ARK API，本身就是 VLM，input_modalities 含 image），
能正确读出芯片型号、功能模块、信号链路、死区电阻配置，甚至电路"原理"
（去耦、TVS 防护、自举、米勒效应）。不是只列器件号。

Codex（GPT-5.6，ChatGPT Plus 订阅）读同一张图更系统——直接给出全桥拓扑图、
电压分压公式、死区电阻分析。原理图识图优先 codex，豆包 VLM 兜底。

## 工作流

1. PDF 转图（150 DPI 够用）：
   `pdftoppm -png -r 150 原理图.pdf /tmp/sch_page`

2. 文本提取兜底（交叉验证器件型号/阻值，VLM 会读错具体值）：
   `pdftotext -layout 原理图.pdf -`   # 逐页看，grep 器件号/阻值

3. 图片喂给 VLM：
   - 豆包：`model=doubao-seed-2-0-lite-260428`，messages 里 image_url 用 `data:image/png;base64,...`
   - Codex：`codex exec "读取图片 /tmp/sch_page-N.png，识别..."`（需在 git 仓库内）

4. 交叉验证：VLM 可能读错具体阻值（本会话把 R55=20kΩ 读成 70kΩ），
   用 pdftotext 的文本结果核对关键器件值、死区电阻、晶振频率。

## 已确认的水声板原理图结构（SCH_Schematic1，4页）

- 第1页 主控: STM32G474RET6 + 4G(USART3) + GPS(UART5/1PPS) + MAX3232 + LED×4 + SMBJ15CA TVS
- 第2页 电源: 24V输入 → 两路 TPMP2359DJ 降压(24V→5V, 24V→12V) → 5V→3.3V LDO
- 第3页 信号链: INA826AIDR 差分放大(G=11) + 1.6V REF + PGA(U11/12/13) + ADC前级滤波 f_c=159kHz
- 第4页 GaN驱动: SN74LVC2G00 与非门(TX_EN互锁) + SN74LVC2G04 反相器 + 2×LMG1210 半桥驱动
  + 4×INN700DA190B GaN(全桥) + MA2YD26/MURS120/SS34 二极管

## 成本

- 豆包 VLM: doubao-seed-2-0-lite-260428, ¥3/百万token 输入, 每页 70-95 秒
- Codex: 走 ChatGPT Plus 订阅额度(非 API 计费), 模型 gpt-5.6
- 本地 qwen2.5vl:3b 太慢(2G显存读4页超时), 不适用于原理图
