#!/usr/bin/env python3
"""Pull a NetEase playlist in full from YesPlayMusic's bundled local API server.

Run while YesPlayMusic is open (its NeteaseCloudMusicApi server listens on
127.0.0.1:10754). No auth needed — the full track list comes back without login.

Usage:
    fetch_liked_songs.py [playlist_id] [out.json]

Defaults: playlist_id = 2667995820 (user 搞点饭吃吃捏's liked list, 2563 songs),
out = /home/sato/persona/netEase-liked-songs-full.json
"""
import json
import sys
import time
import urllib.request

PLAYLIST = sys.argv[1] if len(sys.argv) > 1 else "2667995820"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/home/sato/persona/netEase-liked-songs-full.json"


def fetch(offset):
    url = f"http://127.0.0.1:10754/playlist/track/all?id={PLAYLIST}&limit=1000&offset={offset}"
    for attempt in range(3):
        try:
            return json.load(urllib.request.urlopen(url, timeout=30))
        except Exception as e:
            print(f"  offset={offset} retry {attempt + 1}: {e}", file=sys.stderr)
            time.sleep(1)
    return None


all_songs = []
for off in range(0, 5000, 1000):  # cap at 5000; stops early when a page is short
    d = fetch(off)
    songs = d.get("songs", []) if d else []
    if not songs:
        break
    all_songs.extend(songs)
    print(f"offset={off}: +{len(songs)}")
    if len(songs) < 1000:
        break
    time.sleep(0.5)

uniq = {}
for s in all_songs:
    uniq[s["id"]] = s

out = [
    {
        "id": s["id"],
        "name": s["name"],
        "artists": [a["name"] for a in s.get("ar", [])],
        "album": s.get("al", {}).get("name", ""),
    }
    for s in uniq.values()
]
with open(OUT, "w") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print(f"saved {len(out)} tracks -> {OUT}")
