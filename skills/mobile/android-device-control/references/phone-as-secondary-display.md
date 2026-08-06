# Phone as a secondary display (waybar offload)

Worked example 2026-08-06: show the PC's waybar on an Android phone standing in as a second monitor, freeing the main screen. Full stack: Hyprland headless output → wayvnc → waybar multi-bar → adb reverse → AVNC on the phone. All USB-based, no WiFi needed.

## Architecture

```
Hyprland HEADLESS-1 (virtual output, 1600x720 landscape)
   └─ waybar -c ~/.config/waybar/phone.jsonc  (row 1: workspaces/window/clock/tray/network/audio/battery)
   └─ waybar -c ~/.config/waybar/phone2.jsonc (row 2: cpu/temp/memory/disk/mouse-battery/power, margin-top stacked)
        ↓ wayvnc -o HEADLESS-1 -d  (VNC server, listens 127.0.0.1:5900, remote input disabled)
        ↓ adb reverse tcp:5900 tcp:5900  (USB tunnel: phone sees PC localhost:5900)
   Android phone: AVNC app → connect 127.0.0.1:5900 (no password)
```

## Step-by-step (Hyprland 0.56, Arch)

```bash
# 1. Create + size the virtual output (0.56 uses `hyprctl output create headless`, not the old `outputs` command)
hyprctl output create headless
hyprctl keyword monitor "HEADLESS-1,1600x720@60"     # match phone orientation; list with `hyprctl monitors all -j`

# 2. waybar multi-bar: copy config per bar, add output pin + stack offset
cd ~/.config/waybar
cp config.jsonc phone.jsonc && cp style.css phone.css
# phone.jsonc: add "output": ["HEADLESS-1"], pick row-1 modules, "height": 30
cp config.jsonc phone2.jsonc && cp style.css phone2.css
# phone2.jsonc: same output pin, row-2 modules, "margin-top": "30" to stack below row 1

# 3. Start bars + VNC (all long-lived: background processes)
#    NOTE (waybar v0.15, verified): `-b <id>` is IGNORED — must use explicit `-c <path>` per bar
waybar -c ~/.config/waybar/phone.jsonc
waybar -c ~/.config/waybar/phone2.jsonc
wayvnc -o HEADLESS-1 -d        # -d disables remote input; default listen 127.0.0.1:5900

# 4. USB tunnel + phone client
adb reverse tcp:5900 tcp:5900
# Phone: install AVNC (com.gaurav.avnc), connect 127.0.0.1:5900, no password
```

## Verified quirks

- **Hyprland 0.56 CLI renamed**: `hyprctl outputs` → `hyprctl monitors` (`monitors all -j` for JSON incl. inactive). `hyprctl output create headless` returns `ok`.
- **waybar v0.15 multi-bar: `-b <id>` is BROKEN (verified 2026-08)** — the flag is silently ignored; the process loads the DEFAULT `config.jsonc` and renders an identical bar on EVERY output (main screen polluted with extra bars, rows duplicated). There is no `-o/--output` flag either. Use ONE process per bar with explicit `-c <path>`: `waybar -c ~/.config/waybar/phone.jsonc`. Each bar config pins `"output": ["HEADLESS-1"]` (this key works with `-c`).
- **Stacked rows**: second bar config gets `"margin-top": "<row1 ACTUAL height>"`. waybar bumps a configured `"height": 30` up to the module minimum — the log line `Bar configured (width…, height: 38/42) for output: …` shows the REAL rendered height; use that number for margin-top or rows overlap.
- **Main-screen bar needs its own output pin too**: add `"output": ["eDP-1"]` to `config.jsonc`, otherwise every new waybar instance paints on the main screen as well.
- **Confirm which config loaded**: the log line `Using configuration file <path>` tells you whether `-c`/`-b` actually took effect.
- **Verify without a phone**: `grim -o HEADLESS-1 shot.png` then check pixel content (e.g. PIL: top rows non-black ratio). grim must be installed (`pacman -S grim`).
- **AVNC APK source**: F-Droid page/API 404'd for several VNC clients over proxy; GitHub releases worked: `github.com/gujjwal00/avnc/releases` → `AVNC-<ver>.apk`. Package id is `com.gaurav.avnc` (NOT com.guyvidal.avnc); launch via `adb shell monkey -p com.gaurav.avnc -c android.intent.category.LAUNCHER 1` or `cmd package resolve-activity --brief com.gaurav.avnc` first to find the real entry activity.
- **Connect from the agent**: AVNC has a top address bar — `adb shell input tap` it, `input text "127.0.0.1:5900"`, `input keyevent 66` to connect. If you land on a settings page, you hit the wrong spot; screenshot → re-target (see coordinate-space gotcha in the parent SKILL.md).
- **User feedback loop**: phone standing landscape → make the virtual output landscape (1600x720), and one waybar row overflows → split modules across two stacked rows.
- **adb reverse resets** whenever the adb server restarts — re-run before each session.
