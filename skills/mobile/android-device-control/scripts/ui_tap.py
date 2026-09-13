#!/usr/bin/env python3
"""Locate an Android UI node (by resource-id or text) via uiautomator and tap it.

Written for flaky OEM UIs where button positions shift between pages (consent
wizards, promo banners) and hardcoded pixels go stale. Always locate from a
fresh dump instead of remembering coordinates.

Usage:
    ui_tap.py <resource-id|text> [--tap] [--index N] [--scroll [N]] [--wait S]

    --tap          tap the centre of the match (default: just report it)
    --index N      pick the N-th match when several nodes share the id (default 0)
    --scroll N     if not found, swipe up and re-dump, up to N tries
    --wait S       sleep S seconds before the first dump (page settle)

Exit codes: 0 found, 1 not found / unparsable.

Typical loop for a multi-page flow:

    ui_tap.py com.pkg:id/btn_next --tap --wait 2
    ui_tap.py 继续安装 --tap --scroll 6      # text match, scroll to reveal

Notes verified on HONOR/Android 12 and similar:
- Bounds may be reported in LOGICAL px while `input tap` wants PHYSICAL px. If
  the reported width differs from `wm size`, scale before tapping.
- Re-dump after EVERY page: stacked OEM warning flows add pages, shifting
  everything below.
- A tap can be stolen by an ad/webview row that appears late; if the expected
  screen does not appear, force-stop whatever grabbed the foreground and retry.
"""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = "/opt/android-sdk/platform-tools/adb"
REMOTE = "/sdcard/ui_dump.xml"
LOCAL = "/tmp/ui_dump.xml"


def dump():
    subprocess.run([ADB, "shell", "uiautomator", "dump", REMOTE], capture_output=True)
    subprocess.run([ADB, "pull", REMOTE, LOCAL], capture_output=True)
    try:
        return ET.parse(LOCAL).getroot()
    except ET.ParseError:
        # a fresh page (or a system dialog) can make the dump empty; caller retries
        return None


def centre(node):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
    if not m:
        return None
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def find(root, target):
    if root is None:
        return []
    return [
        n
        for n in root.iter("node")
        if n.attrib.get("resource-id") == target or n.attrib.get("text") == target
    ]


def swipe_up():
    subprocess.run([ADB, "shell", "input", "swipe", "360", "1250", "360", "450", "400"])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    target = args[0]
    do_tap = "--tap" in sys.argv
    index = int(sys.argv[sys.argv.index("--index") + 1]) if "--index" in sys.argv else 0
    scroll_tries = (
        int(sys.argv[sys.argv.index("--scroll") + 1]) if "--scroll" in sys.argv else 0
    )
    if "--wait" in sys.argv:
        time.sleep(float(sys.argv[sys.argv.index("--wait") + 1]))

    hits = find(dump(), target)
    tries = 0
    while not hits and tries < scroll_tries:
        swipe_up()
        time.sleep(1.2)
        tries += 1
        hits = find(dump(), target)
        print(f"  scroll {tries}: {'found' if hits else 'not yet'}")

    if not hits:
        print(f"NOT FOUND: {target} (scrolled {tries}x)")
        return 1

    node = hits[min(index, len(hits) - 1)]
    pos = centre(node)
    if not pos:
        print(f"NO BOUNDS for {target}")
        return 1
    print(
        f"FOUND {target!r} idx={index}/{len(hits) - 1} at {pos} "
        f"text={node.attrib.get('text')!r}"
    )
    if do_tap:
        subprocess.run([ADB, "shell", "input", "tap", str(pos[0]), str(pos[1])])
        print("TAPPED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
