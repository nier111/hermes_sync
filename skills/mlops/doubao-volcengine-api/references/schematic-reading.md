# Reading Circuit Schematics with a VLM

Workflow for reading circuit schematic PDFs (or board images). Built for the user's embedded/PCB projects (水声板 GaN 驱动, STM32 主控, etc.).

## Steps

1. **Convert PDF pages to PNG**
   ```bash
   pdftoppm -png -r 150 schematic.pdf /tmp/sch_page
   ```
   150 DPI is enough for a VLM; higher DPI = slower. Output is `/tmp/sch_page-1.png`, `-2.png`, etc.

2. **Extract the text layer for cross-checking part numbers**
   ```bash
   pdftotext -layout schematic.pdf -
   ```
   Text gives component values and designators (R55 20K, LMG1210RVRR, INN700DA190B) but NOT circuit topology — the layout is jumbled coordinates, useless for understanding the circuit, only for verifying exact part values.

3. **Send each page image to a VLM** (doubao-seed-2-0-lite-260428 works great)
   Ask for:
   - chip models + function per chip
   - functional blocks (power entry, conversion, signal chain, interface, protection)
   - connector pinouts
   - signal-chain logic (e.g. "PWM → 与非门互锁 → 反相器整形 → 驱动器")
   - topology (e.g. "双半桥拼接成全桥 H桥"), NOT just a parts list

4. **Cross-verify VLM output against pdftotext.** The VLM gets topology/principle right but can misread individual component values — tested: it reported "R55 = 70kΩ" when the text layer clearly showed `R55 20K` (and the schematic formula `R = (900/t) - 25`, "20ns 对应 20K"). Check every part number/value the VLM states.

## Known-good model

`doubao-seed-2-0-lite-260428` (Volcano Ark, image input). ~70-95s per page at 150 DPI. Reads the GaN driver stage, STM32G474RET6 minimal system, 4G/GPS/RS232 modules, and power tree correctly.

## Pitfalls

- **Local ollama qwen2.5vl:3b (2GB VRAM) times out** on multi-page high-res schematics — do NOT use it for this task. Use a cloud VLM (Doubao, or Qwen/Gemini via OpenRouter).
- **pdftotext alone is insufficient** — it gives a flat list of designators/values, no connectivity or principle. A VLM is required for "reading the schematic" in any meaningful sense.
- **PDF may be multi-page** — always check `pdftoppm` produced N pages and analyze all of them (a schematic often spans 主控/电源/信号链/驱动 across 4 sheets).
