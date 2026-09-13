# Lua runtime, layout and state notes (Xiaomi band Lua engine)

Observed on Xiaomi Smart Band 10 / firmware 3.1.16, NuttX + LVGL Lua engine.
Shared by Mi Band 8 Pro / 9 / 9 Pro / 10 / 10 Pro / 11, Redmi Watch 4 / 6,
Watch S3 / S4 / S5 — APIs drift between firmwares, always retest on target.

## Entry point and screen model

- `app/lua/main.lua` runs on the **current screen** (`lvgl.scr_act()`).
- The `.fprj` declares one `Widget Shape="34"` whose `Name` is the URL-escaped
  Lua path `app_lua%2Fmain.lua`; it covers the whole panel.
- If the screen is invalid/hidden the face should hide itself.

## Geometry that actually matters

| Fact | Value |
|---|---|
| Panel (reported by `lvgl.HOR_RES()/VER_RES()`) | 212 x 520 |
| Usable safe area after rounded corners | ~`x 12..200`, `y 34..508` |
| Corner radius to render in previews | ~28 px |
| Tall element minimum top | y >= 30 |

The panel reports a full rectangle, so **nothing in the API tells you about the
corner curve** — a face laid out at y=18 looks clipped on hardware while the
numbers pass every static check. Render previews through a rounded mask
(`ImageDraw.rounded_rectangle` on a mask + `Image.composite`) so clipping is
visible before flashing.

## Text and fonts

- `lvgl.Font("misansw_demibold", size)` is available on many builds; fall back
  to `lvgl.BUILTIN_FONT.MONTSERRAT_14` if the named face is rejected. Wrap in
  `pcall` so an unsupported name cannot kill the face at load.
- **No CJK coverage**: Chinese/kana text renders as `□` boxes. There is no
  runtime API to detect this — enforce ASCII in CI instead.
- Non-ASCII punctuation (middle dot `·`, arrows, em dashes) fails identically.
  Use `/`, `-`, `|` instead.

## dataman — the data bus

- Publisher/subscriber. Callbacks fire **only on change**, not every frame.
- Numeric values are **Q24.8 scaled**: divide by `0x100` / 256
  (`1.0` -> 256, `1.5` -> 384). Clocks report `timeHour`, `timeMinute`,
  `timeSecond`, `timeSecondLow`; also `dateYear/Month/Day/Week`,
  `healthStepCount`, `healthHeartRate`, `systemStatusBattery`, etc.
- **Never nest a `subscribe` inside another `subscribe`** — recursion +
  memory leak + bootloop. All subscriptions at file top level.
- Q24.8 shift also means you can derive sub-second behaviour from
  `timeSecondLow` (e.g. a blinking delimiter on odd/even seconds).

## Timers, screen lifecycle, persistence

```lua
local t = lvgl.Timer { period = 1000, paused = false, cb = function() ... end }

function ScreenStateChangedCB(pre, now, reason)
    if pre ~= "ON" and now == "ON" then t:resume()
    elseif pre == "ON" and now ~= "ON" then t:pause() end
end
```

- Do **not** treat a 1 Hz timer as a clock. Store an absolute end time and
  recompute: `remaining = end_at - os.time()`. Screen-off can suspend the face
  and the callbacks you "expect" may never run.
- `SCRIPT_PATH` is read/write and survives face reinstalls (deleted only when
  the face is removed) — this is the place for settings and state.

## State-file versioning pattern

A plain `key=value` file works well. The subtle part is migration:

```lua
local STATE_VERSION = 2

local function load_state()
    local f = io.open(STATE_FILE, "r")
    if not f then
        state.version = STATE_VERSION     -- fresh install: mark as current
        return
    end
    for line in f:lines() do ... end       -- read version=, mode=, task1=...
    if state.version == nil or state.version < STATE_VERSION then
        -- migrate: reset the changed fields only, keep user data
    end
    state.version = STATE_VERSION
end
```

Pitfalls proven by the PC harness:

- **Do not initialise the sentinel to the current version.** If `state.version`
  starts at `STATE_VERSION`, a legacy file with no `version=` line is treated as
  current, and a fresh install's first save writes a stale-looking version — the
  next load then "migrates" and silently resets an in-flight timer.
- Decide migration by **"version line present?"**, not by the default value.
- Migrate field-by-field: reset timer state, preserve counters and user toggles.
- After changing a default (e.g. 25 -> 50 min), bump `STATE_VERSION` so existing
  installs converge instead of keeping the old value forever.

## Static check list for `tests/validate.py`

Cheap regex checks over `main.lua` catch most shipping bugs:

- no `os.execute`
- no character with `ord(c) > 127` (font coverage)
- no `io.open("/...")` absolute paths
- exactly N top-level `dataman.subscribe` calls (catches accidental nesting)
- parse every `x = N, y = N, w = N, h = N` literal and assert:
  `x + w <= 202`, `y + h <= 512`, and no tall (`h >= 60`) element above y=30
- `.fprj`: `DeviceType == "466"`, widget `Width/Height == 212/520`,
  XML declaration encoding matches the file's real bytes

## PC simulation harness

`scripts/simulate_lua_watchface.lua` runs the real `main.lua` under plain `lua`
with stubbed `lvgl` / `dataman` / `vibrator`. Two stub details that matter:

- Child widgets are created as `parent:Label{...}` — a **method call**, so the
  first argument is the parent object and the **props table is the second**
  argument. A stub written as `function child(p)` silently loses all props and
  every widget becomes an empty table.
- Record `onevent` handlers per object, not in creation order: the timer card's
  tap handler is registered *after* the row buttons in typical layouts. Identify
  containers by a structural property (e.g. `h >= 100`) instead of position.
