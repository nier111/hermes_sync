#!/usr/bin/env bash
# Download + validate a random cat GIF (no API key needed).
# Usage: fetch_cat_gif.sh [output_path]
# Falls back to the local proxy at 127.0.0.1:7890 if a direct fetch times out.
set -euo pipefail

OUT="${1:-$HOME/.hermes/stickers/cat_$(date +%s).gif}"
mkdir -p "$(dirname "$OUT")"
URL="https://cataas.com/cat/gif?t=$(date +%s)"

fetch() { curl -sL --max-time 30 "$@" "$URL" -o "$OUT" || true; }

fetch
if ! file "$OUT" 2>/dev/null | grep -qi "gif image"; then
    echo "direct fetch failed/timed out, retrying via 127.0.0.1:7890" >&2
    fetch -x http://127.0.0.1:7890
fi

# Validate: curl may exit 28 (timeout) while the file is actually complete.
if ! file "$OUT" | grep -qi "gif image"; then
    echo "ERROR: download is not a valid GIF" >&2
    rm -f "$OUT"
    exit 1
fi

python3 - "$OUT" <<'EOF'
import sys
from PIL import Image
p = sys.argv[1]
im = Image.open(p)
im.seek(0)
print(f"OK {p}: {im.format} {im.size[0]}x{im.size[1]} {im.n_frames} frames")
EOF
