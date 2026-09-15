#!/usr/bin/env bash
# verify_render_fidelity.sh — prove a rewritten/compressed office document still matches the original.
#
# Checks, in order:
#   1. rendered page count equal
#   2. whitespace-normalized pdftotext SHA-256 equal
#   3. per-page pixel difference (compare -metric AE), page by page
#
# Usage: bash verify_render_fidelity.sh <original> <candidate> [outdir] [dpi=150]
#
# Non-PDF inputs are rendered with LibreOffice (isolated profile). NOTE: LibreOffice is only the
# renderer here — if the user opens the file in WPS/Word, that engine's rendering is the one that
# decides. See references/inplace-media-replacement-and-wps-native.md for rendering with WPS.
#
# Exit: 0 fully verified | 1 usage/missing input | 2 missing dependency
#       3 factual mismatch (pages or text differ) | 4 pixel differences found, needs eyeball

set -euo pipefail

ORIG=${1:-}; CAND=${2:-}; OUTDIR=${3:-./fidelity-check}; DPI=${4:-150}
if [ -z "$ORIG" ] || [ -z "$CAND" ]; then
  echo "usage: bash verify_render_fidelity.sh <original> <candidate> [outdir] [dpi=150]" >&2
  exit 1
fi
for f in "$ORIG" "$CAND"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
done

missing=""
for c in pdfinfo pdftotext pdftoppm python3; do
  command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
COMPARE=$(command -v compare || true)
[ -n "$COMPARE" ] || missing="$missing imagemagick"
if [ -n "$missing" ]; then
  echo "missing dependencies:$missing" >&2
  echo "Arch install: /usr/bin/sudo -A pacman -S --needed poppler imagemagick" >&2
  exit 2
fi

mkdir -p "$OUTDIR/render"
WORK="$OUTDIR/.pdf"
rm -rf "$WORK"; mkdir -p "$WORK"

# --- render inputs to PDF -----------------------------------------------------
to_pdf() { # $1 = input, $2 = tag -> echoes pdf path
  local in=$1 tag=$2
  if [ "${in,,}" = "pdf" ] || [ "$(head -c 4 "$in")" = "%PDF" ]; then
    local dst="$WORK/$tag.pdf"; cp -f "$in" "$dst"; echo "$dst"; return 0
  fi
  if ! command -v soffice >/dev/null 2>&1; then
    echo "ERROR: $in is not a PDF and soffice is unavailable to render it" >&2
    echo "       (python-docx and friends cannot render; a real renderer is required)" >&2
    return 1
  fi
  local prof; prof=$(mktemp -d /tmp/lo-profile.XXXXXX)
  soffice -env:UserInstallation="file://$prof" --headless \
    --convert-to pdf --outdir "$WORK" "$in" >/dev/null 2>&1 || true
  rm -rf "$prof"
  local produced; produced=$(find "$WORK" -maxdepth 1 -name "$(basename "${in%.*}").pdf" | head -1)
  if [ -z "$produced" ]; then
    echo "ERROR: rendering produced no PDF for $in (a silent converter failure writes nothing)" >&2
    return 1
  fi
  local dst="$WORK/$tag.pdf"; mv -f "$produced" "$dst"; echo "$dst"
}

PA=$(to_pdf "$ORIG" a) || exit 3
PB=$(to_pdf "$CAND" b) || exit 3
[ -s "$PA" ] && [ -s "$PB" ] || { echo "ERROR: empty render" >&2; exit 3; }

PG_A=$(pdfinfo "$PA" | awk '/^Pages:/{print $2}')
PG_B=$(pdfinfo "$PB" | awk '/^Pages:/{print $2}')
echo "pages: original=$PG_A candidate=$PG_B"
[ "$PG_A" = "$PG_B" ] || { echo "FAIL: page count differs" >&2; exit 3; }

# --- normalized text ----------------------------------------------------------
python3 - "$PA" "$PB" <<'PY'
import hashlib, os, re, subprocess, sys, tempfile
def norm(p):
    t = tempfile.NamedTemporaryFile(suffix=".txt", delete=False).name
    subprocess.run(["pdftotext", "-layout", p, t], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    s = open(t, encoding="utf-8", errors="replace").read(); os.unlink(t)
    return re.sub(r"\s+", "", s)
a, b = norm(sys.argv[1]), norm(sys.argv[2])
ha = hashlib.sha256(a.encode()).hexdigest()
hb = hashlib.sha256(b.encode()).hexdigest()
print(f"text: {len(a)} vs {len(b)} non-space chars | sha256 {ha[:12]} vs {hb[:12]} | identical={ha == hb}")
sys.exit(0 if ha == hb else 3)
PY
if [ $? -ne 0 ]; then
  echo "FAIL: normalized text differs — the rewrite changed content, not just image bytes" >&2
  exit 3
fi

# --- per-page pixels ----------------------------------------------------------
echo "pixel diff per page (AE = differing pixels; 0 is identical):"
worst=0
for n in $(seq 1 "$PG_A"); do
  "$(command -v pdftoppm)" -f "$n" -l "$n" -singlefile -r "$DPI" -png "$PA" "$OUTDIR/render/orig-$n" >/dev/null 2>&1
  "$(command -v pdftoppm)" -f "$n" -l "$n" -singlefile -r "$DPI" -png "$PB" "$OUTDIR/render/cand-$n" >/dev/null 2>&1
  ae=$("$COMPARE" -metric AE "$OUTDIR/render/orig-$n.png" "$OUTDIR/render/cand-$n.png" null: 2>&1 | tr -dc '0-9' || true)
  ae=${ae:-0}
  printf '  page %-3s AE=%s\n' "$n" "$ae"
  [ "$ae" -gt "$worst" ] && worst=$ae
done

echo
if [ "$worst" -eq 0 ]; then
  echo "OK: same page count, identical normalized text, pixel-identical on every page."
  echo "Reminder: that is fidelity in THIS renderer. If the user opens the file elsewhere,"
  echo "hand them the deliverable for one eyeball pass before they submit."
  exit 0
else
  echo "PIXEL DIFFERENCES FOUND (worst page AE=$worst). Inspect $OUTDIR/render/*.png side by side."
  echo "Do not report this as verified. Common causes: substituted font, dropped heading,"
  echo "image repositioned, changed wrap. Consider the in-place / user-editor path instead."
  exit 4
fi
