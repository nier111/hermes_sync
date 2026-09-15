# Headless Office conversion + size verification (validated on Arch, LibreOffice 26.8)

Every command below was actually run against a 36.9 MiB legacy `.doc` report. Treat them as
transcribed, not invented — but re-verify artifacts on each new file rather than trusting the
recipe blindly.

## 1. Isolated headless profile (mandatory)

LibreOffice reuses `~/.config/libreoffice`; a headless run can collide with the user's open WPS /
LibreOffice. Always pass a throwaway profile:

```bash
p=$(mktemp -d /tmp/lo-profile.XXXXXX)
soffice -env:UserInstallation="file://$p" --headless --convert-to <filter> --outdir <dir> <input>
rm -rf "$p"
```

Output lands in `--outdir` named `<input-stem>.<new-ext>`. Always check the output exists and is
non-trivial; a silent failure writes nothing.

## 2. Filter names that work

| Direction | Filter string |
|---|---|
| `.doc` → `.docx` | `docx:Office Open XML Text` |
| `.docx` → `.doc` (Word 97) | `doc:MS Word 97` |
| anything → PDF (verify) | `pdf` / `writer_pdf_Export` |

Legacy `.doc` is a CFB container, **not** a zip — you cannot unpack it to reach `word/media`.
Convert to `.docx` first, do the work, then convert back so the submission platform still sees the
extension it demanded.

## 3. OOXML media layout

| Format | Embedded media |
|---|---|
| `.docx` | `word/media/*` |
| `.pptx` | `ppt/media/*` |
| `.xlsx` | `xl/media/*` |
| `.odt` | `Pictures/*` |

`zip` is often absent on minimal installs → use Python:

```bash
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" a.docx out/
```

Repack **the same tree** (walk, sort, `zipfile.ZIP_DEFLATED`). Preserving member paths is what keeps
`[Content_Types].xml` / `_rels` consistent; Word and LibreOffice both opened the repacked file and
the `docx` skill's validator returned `{"ok": true, "issues": []}`.

## 4. Inspect before compressing

```bash
find word/media -type f -print0 | sort -z | xargs -0 identify -format '%f | %m | %wx%h | %[colorspace] | %b\n'
find word/media -type f -print0 | xargs -0 identify -format '%f orientation=%[orientation]\n'
du -sh word/media
```

Real observation from the report: 8 images, all JPEG, 3072x4096 / 4096x3072, all
`orientation=Undefined`, 37 MB combined — i.e. phone photos pasted at full resolution into a
13-page document. No scanner artifacts, no transparency, no vector content: the simple
resize + JPEG-quality lever was the whole fix.

## 5. Compression lever that worked

```bash
magick in.jpeg -resize '2000x2000>' -strip \
  -sampling-factor 4:2:0 -interlace Plane -quality 82 'jpeg:out.tmp'
```

Result: 37 MB → 2.5 MB across the 8 images, long edge 2000 px, still print-legible (~6.7 in at
300 dpi). `-auto-orient` belongs *before* `-resize`. Write output with an explicit `jpeg:`/`png:`
format prefix — `magick` cannot infer the format from a name like `photo.jpeg.tmp`.

Skip PNGs that carry an alpha channel unless you intend the transparency to become white:

```bash
magick identify -format '%[channels]' f.png   # contains 'a' => has alpha
```

## 6. Verification recipe (the actual gate)

```bash
for spec in "pdf-original:$ORIG" "pdf-compressed:$OUT"; do
  out=${spec%%:*}; src=${spec#*:}; p=$(mktemp -d)
  soffice -env:UserInstallation="file://$p" --headless --convert-to pdf --outdir "$work/$out" "$src"
  rm -rf "$p"
done
for f in "$work"/pdf-*/*.pdf; do pdfinfo "$f" | grep '^Pages:'; done
# then: pdftotext each, strip all whitespace, sha256-compare
```

Real numbers from the accepted run: both render **13 pages**; whitespace-stripped text 7506 chars,
identical SHA-256 (`3b196744...`) for original `.doc`, compressed `.docx`, and compressed `.doc`.
Final deliverable 2,573,824 B against a 20 MiB cap → 17.55 MiB of headroom.

Package-level check (needs `python-docx`, keep it out of system Python):

```bash
uv run --with python-docx python ~/.hermes/skills/productivity/docx/scripts/docx_validate.py file.docx
```

## 7. Pitfalls that cost time

- `stat -c %s` = bytes; `stat -c %b` = 512-byte blocks. The two gave "2.5 MB" and "9.2 MB" for the
  same file and made the intermediate look wrong. Always quote `%s`.
- `zip: command not found` → don't install a packer; `python3 -m zipfile` / `zipfile` module.
- `No module named 'docx'` from the validator → `uv run --with python-docx ...`, not a system pip
  install.
- LibreOffice keeps a running `wpscloudsvr` / `wpsoffice` process on this box; `pgrep` them before
  assuming a headless conversion raced with the user's editor.
- If a task-only install was needed (LibreOffice is ~541 MiB installed here), remove it afterwards
  with `pacman -Rns libreoffice-fresh` unless the user will convert again soon.
