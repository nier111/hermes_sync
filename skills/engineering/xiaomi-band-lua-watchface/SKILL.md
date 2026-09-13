---
name: xiaomi-band-lua-watchface
description: "Use when building Lua watchfaces for Xiaomi bands."
version: 1.0.0
author: Aoi
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [xiaomi, miband, watchface, lua, lvgl, notify, wine, wearable, fprj]
---

# Xiaomi band Lua/LVGL watchface development

Build, verify and install a **custom watchface (or watchface-embedded app)** on
Xiaomi bands/watches whose runtime is NuttX + LVGL with a Lua engine
(Mi Band 8 Pro/9/9 Pro/10/10 Pro/11, Redmi Watch 4/6, Watch S3/S4/S5).

Verified 2026-09 on Xiaomi Smart Band 10 (212x520, firmware 3.1.16) with:
wine + wine-mono toolchain, Mi Create's `compile.exe`, install through
Notify for Xiaomi (`com.mc.xiaomi1`).

## Route decision first

Before writing firmware, decide the layer. For "make one app easy to reach"
requests (Pomodoro, todos, quick launch), a **watchface-embedded Lua app is the
right answer** — it keeps stock power management, sensors and Bluetooth intact
and is deployable in minutes.

Replacing the whole image with the BEST1503 SDK is a last resort: the public
bring-up proves display/touch/RTOS, not battery management, RTC wake, BT
pairing or health sensors, and it needs a teardown + UART flash.
See the `wearable-ble-re` skill for that device family's link/protocol detail.

## Project shape

```
my-face/
├── my-face.fprj          # DeviceType 466 (band 10), Shape 34 widget -> app/lua/main.lua
├── app/lua/main.lua      # entry point, runs on the watchface screen
├── images/preview.png    # 212x520 preview used by tooling
├── output/my-face.bin    # built package
└── tests/                # static checks + PC simulation
```

Copy `templates/band10.fprj` to start. One `Widget Shape="34"` covering the full
panel is all that is needed for a Lua face.

## Hard runtime rules (all learned the hard way)

1. **ASCII only in UI text.** The band's font pack has no CJK glyphs — Chinese
   renders as a row of small boxes (`□`). Enforce it with a check; do not assume
   the `misansw` face has coverage. Mid-dots `·`, arrows and other
   non-ASCII punctuation break the same way.
2. **Respect the rounded AMOLED corners.** The panel reports 212x520 but the
   corners are curved. Keep every element inside roughly `x 12..200`,
   `y 34..508`. A tall element starting at y=18 gets its top-left eaten.
   Verify visually with a corner-masked preview render, not just numbers.
3. **No `os.execute`** in a watchface; it runs unsandboxed and blocks the
   thread (watchdog reboot). Persist with `io.open(SCRIPT_PATH .. "state.txt")`.
4. **`dataman.subscribe` only at top level.** Nesting one inside another
   recurses and bootloops the face.
5. **Full-screen root needs `add_flag(lvgl.FLAG.EVENT_BUBBLE)`**, otherwise the
   system long-press to change watchface breaks.
6. **Implement `ScreenStateChangedCB(pre, now, reason)`** and pause timers on
   screen-off — the screen-off branch is where battery is won or lost.
7. **Timers are unreliable across screen-off.** Drive countdowns from an
   absolute end timestamp (`os.time()`), recompute remaining on wake, never
   assume N callbacks actually fired.
8. Wrap optional modules in `pcall(require, ...)` (e.g. `vibrator`) so the face
   still loads if a firmware build lacks one.

## Toolchain (Linux)

The editor compilers are Windows/.NET. Mono alone is **not** enough — the
bundled compiler touches WPF (`PresentationCore`), so install wine + wine-mono.

```sh
# the fix for "Could not resolve the signature of a virtual method"
sudo pacman -S --needed wine wine-mono

export WINEPREFIX=~/.local/share/wine-watchface WINEDEBUG=-all
COMPILER=/path/to/Mi-Create/src/compiler/compile.exe

# build (absolute paths only; relative paths inside .fprj fail as "images path is not found")
wine "$COMPILER" -b "$(winepath -w proj.fprj)" "$(winepath -w ./output)" my-face.bin 1461256429

# round-trip check: unpack the built package and hash the Lua back out
wine /path/to/Mi-Create/src/compiler/unpack.exe "$(winepath -w ./output/my-face.bin)"
sha256sum unpacked/my-face/app/lua/main.lua app/lua/main.lua   # must match
```

- The trailing `1461256429` is a required compiler argument, not a version.
- **`.face` vs `.bin`**: for this project the two are the same payload (same
  hash when built with the same name), but the official Notify installer's file
  picker **only lists `.bin`** — always produce the `.bin`.
- Build fresh: delete the output file first, so a stale artifact cannot fool you.

## Verification ladder — do not skip steps

1. `luac -p app/lua/main.lua` — syntax.
2. Static layout/safety checks (see `references/lua-runtime-and-layout.md` for
   the check list: ASCII, safe area, no `os.execute`, subscription count).
3. **PC simulation** — `scripts/simulate_lua_watchface.lua` stubs `lvgl`,
   `dataman` and `vibrator` and actually executes `main.lua` under plain `lua`.
   It prints every label text, then invokes the timer card's tap handler and
   dumps the state file, then reloads. This is where timer defaults, state
   migration and tap wiring get caught *before* touching the band.
4. Compile + unpack + hash-compare (above).
5. Install and confirm the installer reports completion, then have the user
   eyeball the band for clipping and glyph problems.

Step 3 has already paid for itself: it caught a state-migration sentinel bug
and a wrong-handler assumption that would both have shipped silently.

## Installing on the band

Use the Notify for Xiaomi app — see `references/notify-app-upload.md` for the
full onboarding/authkey flow, the required Android permissions, and the ad-row
hijack of the install button. Two symptoms worth memorising:

- Band paired in system Bluetooth but the app shows **nothing** → runtime BLE
  permissions not granted to the app.
- Device listed but **battery 0%** → not authenticated yet (no valid pairing
  key); once the key is right the battery and watchface list populate.

## Pitfalls

- `.fprj` copied from community projects declares `encoding="utf-16"` while the
  file is really UTF-8 — standard XML parsers reject it. Write `utf-8`.
- Edit the Lua, then rebuild: the compiler embeds the Lua that is on disk.
- The installer warns that incompatible models can brick the band; it validates
  and prints a "valid watchface" status, but only after you pick the file.
- Full-screen setup wizards on a **landscape-locked** phone hide their bottom
  buttons; temporarily lock portrait, then restore the user's setting.
- Avoid `adb shell input text` for values containing `:` or other separators —
  it reorders/repeats characters in some OEM input fields. Plain alphanumerics
  are fine. To clear a field: focus it, `input keyevent 123` (MOVE_END), then a
  loop of `input keyevent 67` (DEL).
- Any tappable UI that sits above an ad/upsell row can be hijacked by it; do the
  install with the phone's Wi-Fi and mobile data temporarily off, and restore
  them afterwards.
- Re-dump the UI after every page in a stacked OEM warning flow — button
  positions shift as each extra consent page appears.

## Support files

- `references/lua-runtime-and-layout.md` — LVGL/dataman API notes, scaling
  rules, corner geometry, state-file versioning, static-check list.
- `references/notify-app-upload.md` — Notify onboarding, authkey, permissions,
  upload flow with real UI ids and verified status strings.
- `scripts/simulate_lua_watchface.lua` — runnable PC harness for `main.lua`.
- `templates/band10.fprj` — starter project file for a 212x520 Lua face.
