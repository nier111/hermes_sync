#!/usr/bin/env python3
"""Fetch a full NetEase playlist via YesPlayMusic's bundled local API server.

Usage:
    python3 fetch_netease_playlist.py <playlist_id> [output.json] [port]

Defaults: port 10754 (YesPlayMusic API server), output ./playlist_<id>.json.
Works without auth while the YesPlayMusic app is running. Paginates until
the server returns fewer tracks than requested (end of playlist).

Example: python3 fetch_netease_playlist.py 2667995820 ~/liked.json
"""
import json
import sys
import time
import urllib.request

PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 10754
PLAYLIST_ID = sys.argv[1] if len(sys.argv) > 1 else None
OUT = sys.argv[2] if len(sys.argv) > 2 else None
LIMIT = 1000

if not PLAYLIST_ID:
    print(__doc__)
    sys.exit(1)

BASE = f"http://127.0.0.1:{PORT}"


def fetch(offset: int, attempt: int = 0):
    url = f"{BASE}/playlist/track/all?id={PLAYLIST_ID}&limit={LIMIT}&offset={offset}"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return json.load(r)
    except Exception as e:
        if attempt < 2:
            time.sleep(1)
            return fetch(offset, attempt + 1)
        raise


all_songs, seen = [], set()
offset = 0
while True:
    data = fetch(offset)
    songs = data.get("songs", [])
    if not songs:
        break
    added = 0
    for s in songs:
        if s["id"] not in seen:
            seen.add(s["id"])
            all_songs.append(s)
            added += 1
    print(f"offset={offset}: +{len(songs)} (new {added}), total {len(all_songs)}")
    if len(songs) < LIMIT:
        break
    offset += len(songs)
    time.sleep(0.4)

out = [{"id": s["id"], "name": s["name"],
        "artists": [a["name"] for a in s.get("ar", [])],
        "album": s.get("al", {}).get("name", "")} for s in all_songs]
path = OUT or f"playlist_{PLAYLIST_ID}.json"
with open(path, "w") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print(f"saved {len(out)} tracks -> {path}")
