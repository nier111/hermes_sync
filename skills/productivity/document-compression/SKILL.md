---
name: document-compression
description: "Use when a doc/pdf/pptx exceeds a size cap; slim it."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [documents, docx, doc, libreoffice, imagemagick, submission, verification]
    related_skills: [docx, pdf, powerpoint, ocr-and-documents]
---

# Reducing oversized documents to fit a size cap

Use when a document is too large to submit / upload / email and the cause is embedded media — an
internship report full of phone photos, a deck of screenshots, a scan-heavy PDF. Also use when the
user asks to "compress the images inside this file" or "it must be under 20 MB".

Do the work and verify it. Never answer with "just compress the pictures in Word" and hand the
task back — the deliverable is a real file that opens, keeps its page count, and is measurably
under the cap.

## Non-negotiables

1. **Back up before touching anything**, and prove the backup is identical (`sha256sum` both).
   Never write to the user's original file. Keep the backup even after success.
2. **Keep the original container format for the deliverable.** A platform that asks for `.doc`
   must receive `.doc`, not `.docx`. Convert out for processing, convert back at the end.
3. **Exit code 0 is not verification.** The gate is: same rendered page count, identical normalized
   text, valid package. Report those real numbers, not "should be fine now".
4. **Compress the media, not the layout.** Text, tables, styles and image *positions* must survive;
   only pixel dimensions and JPEG quality change.

## Workflow

Run `bash scripts/shrink_office_media.sh <input.doc|.docx> <outdir> [max_edge] [quality]` to do
steps 1–7 automatically (it renders and verifies at the end and exits 3 on mismatch). Details and
the exact command forms are in `references/libreoffice-headless-conversion.md`.

1. **Measure.** `stat -c %s <file>` (bytes), `file <file>`, and the actual platform cap. Check
   whether the cap is MB (10^6) or MiB (2^20) and report against the stricter reading.
2. **Back up + hash-verify** the original into `<stem>-original-backup.<ext>` beside it.
3. **Get the file into an unzippable OOXML container.** Legacy `.doc` cannot be unzipped — convert
   it with headless LibreOffice first (`--convert-to 'docx:Office Open XML Text'`); `.docx`/`.pptx`
   can be copied as-is.
4. **Find what is actually big** — unpack and inspect `word/media` (`ppt/media` for decks, `xl/media`
   for workbooks) with `identify -format '%f %m %wx%h orient=%[orientation] %b'`. Don't guess;
   report the biggest few files.
5. **Recompress media** with ImageMagick: long edge down to ~2000 px, `-auto-orient`, `-strip`,
   `-sampling-factor 4:2:0 -interlace Plane`, `-quality 82`. 2000 px ≈ 6.7 in at 300 dpi — enough
   for printed report figures. Skipping alpha PNGs prevents transparent screenshots turning white.
6. **Repack** the same tree with Python `zipfile` (never assume the `zip` binary exists).
7. **Convert back** to the platform-required format if it was `.doc`.
8. **Verify** original vs deliverable: render each to PDF, compare `Pages:` and the SHA-256 of
   whitespace-stripped `pdftotext` output; run the package validator when available
   (`uv run --with python-docx python ~/.hermes/skills/productivity/docx/scripts/docx_validate.py <file>`).
9. **Clean up** the temp work tree, keep the backup, and delete task-only packages if LibreOffice
   was installed just for this one conversion (this machine is resource-tight; keep it only if the
   user will convert again soon).

## What to report

Exact byte sizes for original / deliverable / backup, the reduction percentage, the margin left
under the cap, page count before and after, and that the text is byte-identical after
normalization. Give absolute paths in plain text (CLI). Add one honest caveat — LibreOffice round
trips can shift subtle formatting, so a quick eyeball of image placement in WPS is cheap insurance.

## Pitfalls

- **`zip` may not be installed** → repack with `python3 -c "import zipfile..."` / a small heredoc.
  Do not install a packer just for this.
- **`stat -c %b` reports 512-byte blocks, not bytes.** Use `%s`. Mixing them produced a phantom
  "2.5 MB vs 9.2 MB" confusion; always re-check sizes with `%s`.
- **`python-docx` may be missing** → run validators through `uv run --with python-docx python ...`
  instead of pip-installing into system Python.
- **EXIF orientation**: if `%[orientation]` is not `Undefined`, apply `-auto-orient` *before*
  resizing or the shrunk image can come out rotated.
- **Format detection breaks on renamed temp files** — write ImageMagick output with an explicit
  `jpeg:`/`png:` prefix and then `mv`, don't write `image.jpeg.tmp`.
- **LibreOffice headless needs an isolated profile**: pass
  `-env:UserInstallation="file://$(mktemp -d)"`, otherwise it can collide with the user's running
  WPS/LibreOffice profile. Delete the temp profile afterwards.
- **All-JPEG media means pure quality/dimension tuning.** Only reach for a re-encode-to-WebP or a
  PDF-level shrink if the same content is genuinely needed at that resolution; try the simple lever
  first and measure.
- Do not downscale to something like 1000 px "to be safe" — text in figures stops being readable
  and the submission gets rejected for the wrong reason.
- Do not claim success from a conversion that printed no output file; check the artifact exists and
  is non-trivial in size at every stage.

## Support files

- `scripts/shrink_office_media.sh` — end-to-end pipeline with built-in backup, media recompression,
  repack, back-convert and render/text verification.
- `references/libreoffice-headless-conversion.md` — validated headless commands, OOXML media layout,
  the verification recipe, and a worked example with real before/after numbers.
