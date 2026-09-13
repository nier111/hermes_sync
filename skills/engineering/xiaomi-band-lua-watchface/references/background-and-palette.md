# Backgrounds, palette and AMOLED legibility

Verified 2026-09 on Xiaomi Smart Band 10 (212x520 AMOLED, firmware 3.1.16).
Use when a face "works but looks plain" and needs artwork behind the text.

## Draw the background from primitives, not an image

Resist shipping a picture when someone asks for a themed background:

- this runtime decodes PNG slowly — community reports of 1-2 FPS on faces that
  decode images each redraw,
- the LVGL binary image format is **firmware-version specific** and cannot be
  validated from the host, so an image asset is a blind gamble per firmware
  (and each failed gamble costs the user a delete + re-upload cycle),
- primitives are objects already proven to work on the device and cost nothing
  at runtime.

A night-sky look with nothing but `lvgl.Object` children:

| Element | Implementation |
|---|---|
| vertical gradient | one full-width rectangle per band, `bg_color` stepping a few RGB units per band |
| stars / fireflies | tiny square objects with `radius = size // 2` (renders as a circle) |
| distant hills | one enormous circle per hill — only its top arc is on screen |
| brightness variation | vary the **colour**, not the opacity |

Create them immediately after the root object and **before** any widget: child
creation order is z-order. Give them `clear_flag(lvgl.FLAG.SCROLLABLE)` and
`add_flag(lvgl.FLAG.EVENT_BUBBLE)` so they never swallow taps meant for the
cards above them.

## Place the interest where it is actually visible

Most of the panel ends up covered by cards and rows. Before choosing where the
glow or the brightest band goes, work out which strips stay exposed — the first
attempt put the brightest band in the gap *between two row cards* and it read as
a stray stripe rather than a horizon. Re-check with the preview renderer, which
composites the same colours.

## The bands must tile the panel exactly

Stacked bands leave a bare strip if their heights do not add up. Make it a static
check rather than an eyeball:

```python
bands = [int(m) for m in re.findall(r"\{\s*(\d+),\s*\"#", lua)]
assert sum(bands) == 520, f"gradient bands sum to {sum(bands)}"
```

Keep the palette table mirrored in the preview script, and keep the two lists
adjacent so a mismatch is visible in review.

## AMOLED rules for a text-heavy face

- Dark background, bright text: a bright or busy image behind small text hurts
  legibility, drains battery and risks burn-in. Say so when the user asks for a
  film still or any bright artwork, and offer an original dark palette instead.
- Keep the top and bottom ~30 px calm as well as the rounded corners.
- Prefer `/`, `-`, `|` over non-ASCII separators (no glyph coverage).

## Preview fidelity

The preview is a Pillow render, so its font metrics are **not** the band's.
Treat it as a layout/colour/clipping check, never a typography check — only the
device is authoritative for how text actually looks.
