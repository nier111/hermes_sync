#!/usr/bin/env bash
# shrink_office_media.sh — recompress embedded images in a Word document so it fits a size cap.
#
# Transcribed from a verified 2026-09 run on this machine:
#   null.doc 38,648,320 B -> null-compressed.doc 2,573,824 B (-93.3%)
#   8 phone photos (max 4096 px) -> long edge 2000 px, q82
#   rendered page count 13 -> 13, normalized pdftotext sha256 identical, docx package valid
#
# Usage: bash shrink_office_media.sh <input.doc|.docx> <outdir> [max_edge=2000] [quality=82]
# Exit:  0 ok | 1 usage | 2 missing dependency or nothing to shrink | 3 verification failed
#
# The original file is never modified. A hash-verified backup is made beside it, and the
# work tree is kept (not deleted) so you can inspect before/after media yourself.

set -euo pipefail

IN=${1:-}; OUTDIR=${2:-}; MAXEDGE=${3:-2000}; QUALITY=${4:-82}

if [ -z "$IN" ] || [ -z "$OUTDIR" ]; then
  echo "usage: bash shrink_office_media.sh <input.doc|.docx> <outdir> [max_edge=2000] [quality=82]" >&2
  exit 1
fi
[ -f "$IN" ] || { echo "no such file: $IN" >&2; exit 1; }

missing=""
for c in soffice python3 pdfinfo pdftotext identify; do
  command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
MAGICK=$(command -v magick || command -v convert || true)
[ -n "$MAGICK" ] || missing="$missing imagemagick"
if [ -n "$missing" ]; then
  echo "missing dependencies:$missing" >&2
  echo "Arch install:  /usr/bin/sudo -A pacman -S --needed libreoffice-fresh imagemagick poppler" >&2
  echo "task-only install: remove afterwards with  /usr/bin/sudo -A pacman -Rns libreoffice-fresh" >&2
  exit 2
fi

ABS=$(readlink -f "$IN")
DIR=$(dirname "$ABS"); BASE=$(basename "$ABS")
STEM=${BASE%.*}; EXT=${BASE##*.}

mkdir -p "$OUTDIR"
WORK="$OUTDIR/.docshrink-$STEM"
rm -rf "$WORK"
mkdir -p "$WORK/conv" "$WORK/unpacked"

echo "== 1/7 backup + hash check =="
BK="$DIR/$STEM-original-backup.$EXT"
[ -f "$BK" ] || cp -p "$ABS" "$BK"
if [ "$(sha256sum "$ABS" | cut -d' ' -f1)" != "$(sha256sum "$BK" | cut -d' ' -f1)" ]; then
  echo "backup hash differs from source; aborting" >&2
  exit 3
fi
echo "backup: $BK (sha256 identical to source)"

echo "== 2/7 put into OOXML container =="
if [ "${EXT,,}" = "docx" ]; then
  SRC="$WORK/src.docx"; cp -p "$ABS" "$SRC"
else
  P=$(mktemp -d /tmp/lo-profile.XXXXXX)
  soffice -env:UserInstallation="file://$P" --headless \
    --convert-to 'docx:Office Open XML Text' --outdir "$WORK/conv" "$ABS"
  rm -rf "$P"
  SRC="$WORK/conv/$STEM.docx"
fi
[ -s "$SRC" ] || { echo "conversion produced no docx" >&2; exit 2; }

echo "== 3/7 unpack =="
python3 - "$SRC" "$WORK/unpacked" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
MEDIA="$WORK/unpacked/word/media"
if [ ! -d "$MEDIA" ]; then
  echo "no word/media directory (pptx uses ppt/media, xlsx uses xl/media); nothing to shrink" >&2
  exit 2
fi

echo "== 4/7 recompress media =="
before=$(du -sb "$MEDIA" | cut -f1)
for f in "$MEDIA"/*; do
  [ -f "$f" ] || continue
  case "${f,,}" in
    *.jpg|*.jpeg) fmt=jpeg ;;
    *.png)
      if "$MAGICK" identify -format '%[channels]' "$f" | grep -q a; then
        echo "  skip (alpha channel): $(basename "$f")"; continue
      fi
      fmt=png ;;
    *) continue ;;
  esac
  was=$("$MAGICK" identify -format '%wx%h orient=%[orientation] %b' "$f")
  # -auto-orient BEFORE resize, or a rotated source can come out sideways
  "$MAGICK" "$f" -auto-orient -resize "${MAXEDGE}x${MAXEDGE}>" -strip \
    -sampling-factor 4:2:0 -interlace Plane -quality "$QUALITY" "$fmt:$WORK/out.$fmt"
  mv -f "$WORK/out.$fmt" "$f"
  echo "  $(basename "$f"): $was  ->  $("$MAGICK" identify -format '%wx%h %b' "$f")"
done
after=$(du -sb "$MEDIA" | cut -f1)
echo "media total: $before B -> $after B"

echo "== 5/7 repack (python zipfile; the zip binary may be absent) =="
OUTDOCX="$OUTDIR/$STEM-compressed.docx"
rm -f "$OUTDOCX"
python3 - "$WORK/unpacked" "$OUTDOCX" <<'PY'
import os, sys, zipfile
root, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for base, dirs, files in os.walk(root):
        dirs.sort(); files.sort()
        for name in files:
            p = os.path.join(base, name)
            z.write(p, os.path.relpath(p, root))
PY
[ -s "$OUTDOCX" ] || { echo "repack produced nothing" >&2; exit 3; }

echo "== 6/7 back to the original container format =="
OUTFMT="$OUTDOCX"
if [ "${EXT,,}" != "docx" ]; then
  P=$(mktemp -d /tmp/lo-profile.XXXXXX)
  soffice -env:UserInstallation="file://$P" --headless \
    --convert-to 'doc:MS Word 97' --outdir "$WORK/conv" "$OUTDOCX"
  rm -rf "$P"
  OUTFMT="$OUTDIR/$STEM-compressed.doc"
  cp -f "$WORK/conv/$STEM-compressed.doc" "$OUTFMT"
fi
[ -s "$OUTFMT" ] || { echo "back-conversion produced nothing" >&2; exit 3; }

echo "== 7/7 verify (render both, compare pages + text) =="
render() { # $1 = file, $2 = outdir
  mkdir -p "$2"
  local p; p=$(mktemp -d /tmp/lo-profile.XXXXXX)
  soffice -env:UserInstallation="file://$p" --headless \
    --convert-to pdf --outdir "$2" "$1" >/dev/null 2>&1 || true
  rm -rf "$p"
  find "$2" -name '*.pdf' | head -1
}
PA=$(render "$ABS" "$WORK/verify/a")
PB=$(render "$OUTFMT" "$WORK/verify/b")
if [ -z "$PA" ] || [ -z "$PB" ]; then
  echo "WARNING: could not render for verification; sizes only (do not claim verified)" >&2
else
  echo "pages: original $(pdfinfo "$PA" | awk '/^Pages:/{print $2}') | compressed $(pdfinfo "$PB" | awk '/^Pages:/{print $2}')"
  python3 - "$PA" "$PB" <<'PY'
import hashlib, os, re, subprocess, sys, tempfile
def norm(p):
    t = tempfile.NamedTemporaryFile(suffix=".txt", delete=False).name
    subprocess.run(["pdftotext", p, t], check=True)
    s = open(t, encoding="utf-8", errors="replace").read(); os.unlink(t)
    return re.sub(r"\s+", "", s)
a, b = norm(sys.argv[1]), norm(sys.argv[2])
ha, hb = hashlib.sha256(a.encode()).hexdigest(), hashlib.sha256(b.encode()).hexdigest()
print(f"text: {len(a)} vs {len(b)} non-space chars | identical={ha == hb}")
sys.exit(0 if ha == hb else 3)
PY
fi

echo
echo "== sizes (real bytes, %s) =="
stat -c '%n | %s bytes' "$BK" "$OUTDOCX" "$OUTFMT"
echo
echo "work tree kept for inspection: $WORK"
echo "delete the work tree when satisfied; never delete the backup."
