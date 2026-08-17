# Electron app Chinese font rendering fix (QQ on Wayland, verified 2026-08)

## Symptom
Linux QQ (Electron/Chromium, `/opt/QQ`) Chinese text looks "看似有重影但仔细看没有",
blurry/foggy — while terminal (Konsole) and system bar text are crisp. Local VLM
screenshot check (Doubao, see volcano-ark-doubao reference) confirmed: QQ text blurry,
system text crisp; root cause = Electron on XWayland ignoring fontconfig hinting/LCD
config for CJK (Noto Sans CJK is unhinted), forcing soft grayscale AA.

## Fix
User-level .desktop with three flags (overrides system file, survives package updates):

```
~/.local/share/applications/qq.desktop
[Desktop Entry]
Name=QQ
Exec=linuxqq --disable-lcd-text --font-render-hinting=none --ozone-platform-hint=auto %U
...
```

Steps:
1. `cp /usr/share/applications/qq.desktop ~/.local/share/applications/qq.desktop`
2. Edit Exec line to add the three flags.
3. Clear launcher caches: `rm -f ~/.cache/rofi3.druncache ~/.cache/wofi-drun`
   (rofi/wofi drun read user-level .desktop with priority but cache the list).
4. Fully quit QQ (tray exit, not just window close), relaunch from drun.
5. Verify flags took effect: `ps aux | grep /opt/QQ/qq | head -1` shows the flags.

## What actually mattered
- `--ozone-platform-hint=auto` (native Wayland instead of XWayland) was the decisive flag.
- `--disable-lcd-text` ALONE was insufficient (tested first, no improvement).
- `--font-render-hinting=none` pairs with it for unhinted CJK fonts.

## Diagnosis path (before guessing)
1. `grim /tmp/s.png` — Wayland fullscreen screenshot (import -window root fails on
   Wayland; spectacle may fail too; grim works on wlroots).
2. PIL: convert RGB, thumbnail ≤1280px, save JPEG.
3. Feed to Doubao VLM asking "QQ窗口文字是否清晰?对比终端/状态栏?" — returned precise
   verdict naming the cause. Local ollama qwen2.5vl:3b is CPU-only on this box
   (>5min/image, times out) — prefer Doubao for this.
