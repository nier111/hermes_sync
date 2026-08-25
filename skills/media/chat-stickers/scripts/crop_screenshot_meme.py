#!/usr/bin/env python3
"""Crop phone viewer UI/gray bars around white-background memes.

Usage:
  python crop_screenshot_meme.py IMAGE [IMAGE ...] --outdir DIR

The detector finds transitions between nearly-uniform gray viewer rows and the
non-uniform/white meme canvas. It deliberately does NOT use global white-pixel
ratios: black meme strokes may split the white region and cause truncation.
"""
from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from statistics import fmean
from PIL import Image, ImageDraw


def gray_rows(im: Image.Image) -> list[bool]:
    w, h = im.size
    xs = list(range(0, w, max(1, w // 120)))
    rows: list[bool] = []
    for y in range(h):
        values = [sum(im.getpixel((x, y))) / 3 for x in xs]
        mean = fmean(values)
        variance = fmean((v - mean) ** 2 for v in values)
        # Phone viewer background is a nearly uniform medium/dark gray.
        rows.append(variance ** 0.5 < 8 and 40 < mean < 210)
    return rows


def find_canvas(im: Image.Image) -> tuple[int, int]:
    rows = gray_rows(im)
    h = im.height
    top0 = None
    # Ignore status-bar icons near the top; canvas normally starts after 15%.
    for y in range(int(h * 0.15), int(h * 0.50)):
        if sum(rows[y - 15 : y]) >= 14 and sum(rows[y : y + 8]) <= 1:
            top0 = y
            break
    if top0 is None:
        raise RuntimeError("top gray-to-canvas transition not found")

    bottom0 = None
    for y in range(top0 + 100, int(h * 0.90)):
        if sum(rows[y - 8 : y]) <= 1 and sum(rows[y : y + 15]) >= 14:
            bottom0 = y
            break
    if bottom0 is None:
        raise RuntimeError("bottom canvas-to-gray transition not found")

    # Transition detector points at the JPEG-blended boundary row; +1 keeps the
    # first/last clean canvas rows and matches visual boundaries.
    return top0 + 1, bottom0 + 1


def row_is_dark_uniform(im: Image.Image, y: int) -> bool:
    xs = list(range(0, im.width, max(1, im.width // 100)))
    values = [sum(im.getpixel((x, y))) / 3 for x in xs]
    mean = fmean(values)
    variance = fmean((v - mean) ** 2 for v in values)
    return variance ** 0.5 < 8 and mean < 220


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--manifest", default="manifest.json")
    ap.add_argument("--contact-sheet", action="store_true")
    args = ap.parse_args()

    outdir = Path(args.outdir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)
    results = []

    for index, raw in enumerate(args.images, 1):
        src = Path(raw).expanduser()
        im = Image.open(src).convert("RGB")
        top, bottom = find_canvas(im)
        crop = im.crop((0, top, im.width, bottom))
        out = outdir / f"{index:02d}_{src.stem.removeprefix('img_')}.jpg"
        crop.save(out, quality=95, subsampling=0)
        errors = []
        if row_is_dark_uniform(crop, 0):
            errors.append("top gray UI remains")
        if row_is_dark_uniform(crop, crop.height - 1):
            errors.append("bottom gray UI remains")
        results.append({
            "index": index,
            "input": str(src),
            "output": str(out),
            "crop": [0, top, im.width, bottom],
            "result_size": list(crop.size),
            "errors": errors,
        })

    payload = {"count": len(results), "results": results}
    manifest = outdir / args.manifest
    manifest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.contact_sheet:
        tiles = []
        for result in results:
            image = Image.open(result["output"]).convert("RGB")
            image.thumbnail((180, 180))
            tile = Image.new("RGB", (200, 215), "white")
            tile.paste(image, ((200 - image.width) // 2, 20 + (180 - image.height) // 2))
            ImageDraw.Draw(tile).text((8, 3), f"{result['index']:02d}", fill="red")
            tiles.append(tile)
        cols = 6
        sheet = Image.new("RGB", (cols * 200, math.ceil(len(tiles) / cols) * 215), (220, 220, 220))
        for i, tile in enumerate(tiles):
            sheet.paste(tile, ((i % cols) * 200, (i // cols) * 215))
        sheet.save(outdir / "contact_sheet.jpg", quality=90)

    bad = [r for r in results if r["errors"]]
    print(f"processed={len(results)} verified={len(results)-len(bad)} errors={len(bad)}")
    for result in results:
        print(f"{result['index']:02d}|{result['output']}")
    if bad:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
