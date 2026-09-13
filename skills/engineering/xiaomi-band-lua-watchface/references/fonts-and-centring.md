# Fonts, centring and the clock (hardware-verified)

Verified 2026-09 on Xiaomi Smart Band 10 (212x520, firmware 3.1.16), NuttX +
LVGL Lua engine, after the face was actually run on the band.

**This file supersedes two things in `references/lua-runtime-and-layout.md`**,
which was written before hardware bring-up:

- OLD: *"`lvgl.Font("misansw_demibold", size)` is available on many builds; fall
  back to `lvgl.BUILTIN_FONT.MONTSERRAT_14` if the named face is rejected."*
  → the underscore spelling does **not** resolve on this firmware and degrades
  silently; see below.
- OLD: no mention of `text_align` → it is **not honoured at all**; see below.

## Font family: use the hyphenated name

```lua
local FONT_50 = lvgl.Font("MiSans-Regular", 50)
```

`MiSans-Regular` is what the Mi Band 9 Pro and 10 Pro samples use, with sizes up
to 60 for large readouts — so the family is present and scalable on this device.

**A failed font name does not raise.** `pcall(lvgl.Font, "misansw_demibold", 50)`
(the spelling the community MB10-Toolbox uses) did not resolve and silently
yielded the **14 px builtin**. On hardware that looked like:

- nothing is enlarged — the big timer reads small
- text is crammed into the top-left corner of its box
- a large empty area where the layout expected large type

In other words it presents as a **layout** bug. When a face is uniformly tiny,
suspect the font name first, not the coordinates.

## Try a candidate chain, and tag what answered

```lua
local FONT_CANDIDATES = {
    "MiSans-Regular", "MiSans-Demibold", "MiSans",
    "misansw_demibold", "misansw regular",
}
local font_tag = "?"

local function make_font(size)
    for _, name in ipairs(FONT_CANDIDATES) do
        local ok, value = pcall(lvgl.Font, name, size)
        if ok and value then
            if font_tag == "?" then font_tag = name end
            return value
        end
    end
    -- last resort: nearest available builtin size
    ...
end
```

Then print the answer on the device while bringing the face up:

```lua
footer_box:Label { text = "FONT " .. font_tag, text_font = FONT_14, align = lvgl.ALIGN.CENTER }
```

One upload tells you which family resolved. **Remove the tag once confirmed** —
it is bring-up scaffolding, not product copy.

Because `pcall` cannot distinguish "family missing" from "family present but
wrong", also keep a size ladder over `lvgl.BUILTIN_FONT.MONTSERRAT_14` … `_48`
and pick the builtin closest to the requested size. That at least preserves the
typographic hierarchy if no named family resolves.

## Centring: `align`, not `text_align`

`text_align` is **not honoured**. A label created with an explicit `w/h` plus
`text_align = lvgl.ALIGN.CENTER` renders pinned to the box's top-left, which on
hardware reads as "the face is broken in the corner".

The pattern that works (same as MB10-Toolbox and the official samples):

- position a **container** with explicit `x/y/w/h`,
- create the child label **without** `w/h` so it auto-sizes, and give it
  `align = lvgl.ALIGN.CENTER`.

```lua
local clock_box = root:Object {
    x = 6, y = 22, w = 200, h = 62,
    pad_all = 0, border_width = 0, bg_opa = 0,
}
clock_box:clear_flag(lvgl.FLAG.SCROLLABLE)
local clock = clock_box:Label {
    text = "21:07", text_color = "#F3F6FA", text_font = FONT_50,
    align = lvgl.ALIGN.CENTER,
}
```

Left-aligned text inside a row: `align = lvgl.ALIGN.LEFT_MID, x = 14`.

Add one static check that the literal string `text_align =` never appears in the
source — that single regex stops this whole bug class from returning. (Match
`text_align\s*=`, not the bare word, or an explanatory comment trips your own
check.)

## The clock: RTC, not `timeHour`

`timeHour` follows the band's own 12/24h setting, so a face built on it shows
`09:41` for both morning and evening — ambiguous. Use the RTC instead: `%H` is
always 24-hour and ignores the system setting.

```lua
local function refresh_clock()
    clock_label:set { text = os.date("%H:%M") }
end
```

Drive it from the same 1 Hz timer that updates any countdown, and call it once
in `ScreenStateChangedCB` on wake. Side benefit: the face no longer needs the
`timeHour` / `timeMinute` subscriptions at all — fewer top-level
`dataman.subscribe` calls, fewer paths that can fail. Keep the static check's
expected subscription count in sync when you drop them.
