#!/usr/bin/env python3
"""Print an image (or a GIF frame) as ASCII art.

Usage:
    ascii_view.py <path> [frame_index] [width]

Examples:
    ascii_view.py photo.jpg
    ascii_view.py anim.gif 0 70      # first frame, 70 cols
    ascii_view.py anim.gif 21 70     # frame 22 (last) of a 22-frame gif
"""
import sys
from PIL import Image

if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(1)

path = sys.argv[1]
frame = int(sys.argv[2]) if len(sys.argv) > 2 else 0
tw = int(sys.argv[3]) if len(sys.argv) > 3 else 80

im = Image.open(path)
im.seek(frame)
im = im.convert("L")
w, h = im.size
th = max(1, int(h / w * tw * 0.5))  # 0.5 corrects for character aspect ratio
im = im.resize((tw, th))
chars = " .:-=+*#%@"
pix = im.load()
print(f"# {im.format} {w}x{h} frame {frame} -> {tw}x{th} ascii")
for y in range(th):
    print("".join(chars[min(9, pix[x, y] * 10 // 256)] for x in range(tw)))
