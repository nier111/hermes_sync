---
name: study-recall-materials
description: "Use when turning study notes into active-recall printables."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [study, active-recall, handwriting, notes, pdf, printable]
---

# Study Recall Materials

Convert handwritten or digital study notes into printable active-recall material. The goal is not transcription for its own sake: preserve the learner's knowledge structure while removing answers so recall, derivation, and self-assessment happen from memory.

## When to Use

- A learner has handwritten notes/photos and wants a title-only recall sheet.
- Notes should become an A4 worksheet with writing space.
- The user wants to print quickly and needs verified PDFs rather than a proposed layout.
- Mathematical notes contain formulas that require visual inspection, but the chat surface may not render LaTeX.

## Core Principle

Separate three layers:

1. **Cue layer** — chapter titles, property names, theorem names, derivation targets.
2. **Response layer** — blank space where the learner reconstructs definitions, conditions, formulas, and derivations.
3. **Reference layer** — original notes or a faithful archive used only after recall.

Do not copy full formulas into the cue sheet unless the user explicitly requests an answer sheet. A good cue names the task without leaking the result.

## Workflow

### 1. Inspect inputs and recover order

- Enumerate all images/documents and inspect dimensions, orientation, timestamps, page numbers, and filenames.
- Use EXIF or file timestamps only as a provisional order. If the conceptual order differs, keep the original archive in capture order but organize the recall material by knowledge structure.
- For many pages, process in batches and track page count; do not silently omit a page.

### 2. Test handwriting recognition before bulk extraction

- Inspect one or two representative pages first.
- Confirm whether Chinese headings, section numbers, arrows, Greek letters, signs, and subscripts are legible.
- For mathematics, pay special attention to pairs such as `ω/w`, `τ/t`, `n/η`, `+/-`, upper/lower limits, and shifted arguments.
- Mark uncertainty explicitly. Never normalize an uncertain symbol into a confident formula.

When the active model has native vision, an image-analysis tool may attach the raw pixels rather than return a prose OCR transcript. In that case, read the attached image directly in the following model turn; do not mistake the short tool acknowledgement for failed OCR.

### 3. Extract hierarchy, not every line

For each page, collect:

- chapter/section title;
- numbered and unnumbered subheadings;
- named properties and transform pairs;
- proof or derivation targets;
- conditions that deserve their own recall prompt;
- source page identifier for later checking.

Avoid turning side calculations into equal-level headings. Consolidate duplicates that recur across pages, but retain genuinely distinct prompts (for example, a property and its proof).

### 4. Build two recall outputs plus an archive

Default deliverables:

1. **Compact checklist** — usually 1–3 A4 pages, headings and checkboxes only. Best for quick printing and writing on separate paper.
2. **Recall workbook** — each prompt has blank ruled space and a self-rating row such as:
   `□ independently recalled  □ recalled with hint  □ understood only after answer`
3. **Original-note archive** — source images fitted to A4 without cropping, in recoverable source order.

Use logical chapter order in the first two outputs. State clearly if the archive uses capture-time order.

### 5. Make prompts retrieval-oriented

Prefer:

- “State the definition and applicability conditions of …”
- “Derive … from orthogonality.”
- “Write the transform pair and explain the scaling factor.”
- “Give one common sign/index/ROC mistake.”

Avoid vague prompts such as “Review Fourier transform.” One prompt should correspond to one retrievable unit.

### 6. Generate print-ready A4 PDFs

- Use a Chinese-capable embedded or rasterized font.
- Keep margins large enough for ordinary printers.
- Use high-contrast black/dark text on white paper; colored accents must remain distinguishable in grayscale.
- A compact checklist should not waste pages with oversized whitespace.
- A workbook should provide real handwriting room rather than decorative whitespace.
- If a structured PDF library is unavailable, Pillow can render high-resolution A4 page images and save them as a multipage PDF. This is a valid fallback for printables, though it creates image-based PDFs without selectable text.

### 7. Verify the artifact, not just the source

Before reporting completion:

- inspect PDF metadata/page count and confirm A4 dimensions;
- render at least the first page of every output back to PNG;
- for multi-page workbooks, make a low-resolution contact sheet of every page;
- visually check Chinese glyphs, clipping, overlap, margins, page footers, blank-space consistency, duplicates, and unexpectedly empty pages;
- compare generated page counts against the planned counts and source-image count.

Only after these checks should the files be described as ready to print.

## CLI and Formula Formatting

When the user reads in a terminal that does not render LaTeX:

- do not rely on `\\frac`, `\\begin{aligned}`, or other raw LaTeX as the primary display;
- use plain text/Unicode/ASCII in fenced blocks;
- write powers as `z^(-1)`, bounds as `Σ[n=0→N-1]`, and transformations as `x(t-t0)  <--FT-->  X(ω)·exp(-jωt0)`;
- reserve LaTeX source as an optional copyable appendix;
- in generated PDFs, use normal Unicode typography because the PDF is visually rendered.

## Pitfalls

- **Do not equate recognition with correctness.** A faithful extraction may preserve an error in the learner's notes. Label recall material as derived from notes unless formulas were independently checked against a textbook.
- **Do not leak answers into prompts.** A title-only sheet loses its purpose if the result is embedded in the heading.
- **Do not trust filename sorting as notebook order.** Separate archival order from pedagogical order.
- **Do not claim all pages were checked after viewing only page one.** Use a contact sheet for the full workbook.
- **Do not install heavyweight OCR by default for a handful of clear pages.** Native vision plus targeted crops is often faster and better for equations.
- **Do not silently guess ambiguous handwriting.** Ask for a crop or preserve an uncertainty marker.
- **Do not create only one format when printing trade-offs are obvious.** A compact checklist and a spacious workbook serve different costs and study modes.

## Verification Checklist

- [ ] Every source page accounted for
- [ ] Recognition tested on representative handwriting
- [ ] Headings organized into a coherent syllabus
- [ ] Cue sheet contains no accidental answers
- [ ] Chinese font renders correctly
- [ ] PDFs are A4 and have expected page counts
- [ ] First pages visually inspected
- [ ] Full multi-page contact sheet inspected
- [ ] Archive has no cropped source content
- [ ] User receives absolute output paths and a concise printing recommendation

## Supporting Files

- `references/layout-and-verification.md` — recommended A4 layouts, contact-sheet verification, and print decisions.
- `templates/recall-outline.json` — reusable structured outline for checklist/workbook generation.
