# A4 Layout and Verification

## Recommended output set

### Compact checklist

- Target: 1–3 A4 pages.
- Heading: 16–20 pt equivalent.
- Section heading: 11–14 pt.
- Item: 8.5–11 pt with a square checkbox.
- Keep enough whitespace to scan, but optimize for low print cost.
- Recommend duplex printing when the result is two pages.

### Recall workbook

- Target: 3–5 prompts per A4 page for derivation-heavy material; up to 6 for short definitions.
- Each prompt should have a self-rating row and 4–8 ruled lines.
- Keep a consistent footer with subject, purpose, and page number.
- Do not put answers, first equations, or mnemonic completions in the prompt.

### Source archive

- Fit each source page proportionally inside A4.
- Never crop notebook edges merely to fill the sheet.
- Apply EXIF orientation before resizing.
- A small page number outside the image helps map prompts back to sources.

## Pillow A4 fallback

At 180 DPI, an A4 raster canvas is approximately:

```text
width  = 1488 px
height = 2105 px
```

Use a CJK font discovered from the operating system. Rasterized PDFs are appropriate for short-lived print worksheets; explain that they lack selectable text.

## Full-document visual verification

1. Inspect metadata with a PDF information tool and confirm:
   - expected page count;
   - A4 page size (about 595 × 842 pt);
   - no encryption unless requested.
2. Render page 1 of each PDF at readable resolution.
3. Render every page at low resolution.
4. Tile the low-resolution renders into a contact sheet, with pages in reading order.
5. Inspect for:
   - missing or repeated pages;
   - title/footer disappearance;
   - clipped final items;
   - unusual blank pages;
   - inconsistent writing space;
   - CJK tofu boxes or mojibake.
6. For the source archive, visually confirm orientation and full-page containment.

A successful generator run is not sufficient verification; the rendered output is the deliverable.

## Printing recommendation language

Give the user a concrete low-cost choice:

```text
Quick review: print the compact checklist duplex.
Write directly on the sheet: print the workbook.
Keep the archive digital unless a paper answer reference is needed.
```
