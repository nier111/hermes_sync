# In-place media replacement and WPS-native conversion (validated 2026-09, Arch + WPS 12.1.2)

Context: a 38.6 MB legacy `.doc` internship report (14 pages, 8 phone photos at up to 4096 px) had
to go under a 20 MB platform cap. The LibreOffice round trip from
`libreoffice-headless-conversion.md` compressed it successfully, but the user then found two real
defects when opening the results in **WPS**:

- the `.docx` showed the university name (南京信息工程大学) with garbled "花边" glyph artifacts;
- the back-converted `.doc` had **lost the first body heading**.

So: for a document the user must submit, treat the round trip as fallback, not default. Everything
below was actually run on this machine.

## 1. Preferred: replace media inside the original container

Do not re-author the document. Borrow one engine only to *reach* the pixels, then write the
compressed media back into the original container so every other part stays byte-identical.

- `.docx` / `.pptx` / `.xlsx` — already zip: unpack, recompress `word|ppt|xl/media`, repack with the
  same extension and member paths. Nothing else changes, so nothing else can break. This is what
  `scripts/shrink_office_media.sh` does; when the input is already `.docx` it never touches a
  converter, which is the safe case.
- legacy `.doc` — a CFB container, **not** a zip; you cannot reach `word/media` at all without an
  engine that owns the format. Two honest options:
  1. **Hand the compressed images to the user** and let them replace them in their own editor
     (Insert → 从文件, or a find/replace of the picture). This is what happened in the end: the
     compressed JPEGs the pipeline produced were good, the container surgery was the fragile part.
     Ten seconds of user effort, zero fidelity risk, and the submission succeeded.
  2. Drive WPS itself (§3) if the user wants it automated.
- Offering the user's own editor a chance to re-save is also a lever in its own right (§2).

## 2. Free win: the user's editor re-saving shrinks the file

Observed on this exact report: the user opened it in WPS and saved it in place. Result
**38,648,320 B → 2,576,896 B**, still 14 pages, and the rendered first page was pixel-identical to
the original (`compare -metric AE` = 0). Evidence that it was WPS's own save, not damage, came from
the OLE metadata:

```
$ file /home/sato/Downloads/null.doc
Composite Document File V2 Document ... Last Saved Time/Date: Tue Sep 15 20:12:57 2026
... Name of Creating Application: WPS Office_12.1.2.28080_F1E327B ... Number of Pages: 14
```

So before proposing any pipeline: check whether the user's WPS/Word re-save alone clears the cap.
It costs them seconds and preserves their own layout engine's rendering.

## 3. Driving WPS headlessly (pywpsrpc) — needed only for `.doc`

`pywpsrpc` talks to a real WPS install over IPC, so its output matches what the user sees.

One-time-ish config: `~/.config/Kingsoft/Office.conf` must not be in the integrated/prome mode.

```
# default on this box, which makes programmatic conversion unreliable:
wpsoffice\Application%20Settings\AppComponentMode=prome_fushion
# working value for headless conversion:
wpsoffice\Application%20Settings\AppComponentMode=prome_independ
```

**Restore the original value after you are done** — it changes the user's day-to-day WPS behaviour.
Kill stale processes between runs (`pkill -TERM -x wps; pkill -TERM -x wpsoffice;
pkill -TERM -x wpscloudsvr`), or two instances fight over the session.

Converter script (worked; prints each HRESULT so a failure is visible instead of silent):

```python
import os, sys
from pywpsrpc.rpcwpsapi import createWpsRpcInstance, wpsapi
from pywpsrpc.common import S_OK, QtApp
src=os.path.abspath(sys.argv[1]); dst=os.path.abspath(sys.argv[2]); fmt=sys.argv[3]
formats={'doc':wpsapi.wdFormatDocument,'docx':wpsapi.wdFormatXMLDocument,'pdf':wpsapi.wdFormatPDF}
qapp=QtApp(sys.argv)
hr,rpc=createWpsRpcInstance(); print('create',hr,flush=True)
if hr!=S_OK: raise SystemExit(2)
hr,app=rpc.getWpsApplication(); print('app',hr,flush=True)
if hr!=S_OK: raise SystemExit(3)
app.Visible=False
hr,doc=app.Documents.Open(src,ReadOnly=True); print('open',hr,flush=True)
if hr!=S_OK: app.Quit(); raise SystemExit(4)
if os.path.exists(dst): os.remove(dst)
ret=doc.SaveAs2(dst,FileFormat=formats[fmt]); print('save',ret,flush=True)
doc.Close(wpsapi.wdDoNotSaveChanges); app.Quit(wpsapi.wdDoNotSaveChanges)
print('size',os.path.getsize(dst),flush=True)
```

```bash
uv run --with pywpsrpc python /tmp/wps_native_convert.py in.doc out.pdf pdf
```

Its most valuable use here was as a **renderer for verification** (see §4): WPS produced 14-page
PDFs of all four candidate files, so fidelity could be judged in the engine the user actually
opens — which is exactly what the LibreOffice-based gate had failed to do.

## 4. Fidelity gate: page count + normalized text + per-page pixels

```bash
# render every candidate with the SAME engine you will compare in
pdftoppm -f 1 -singlefile -r 150 -png cand.pdf work/render/cand
compare -metric AE work/render/backup.png work/render/cand.png null:   # 0 = pixel-identical
```

```python
# normalized text equality across any number of candidates
import os, re, hashlib, subprocess, tempfile
def norm(p):
    t = tempfile.NamedTemporaryFile(suffix='.txt', delete=False).name
    subprocess.run(['pdftotext', '-layout', p, t], check=True)
    s = open(t, encoding='utf-8', errors='replace').read(); os.unlink(t)
    return hashlib.sha256(re.sub(r'\s+', '', s).encode()).hexdigest()
```

Session result (14-page revision, 8 images): backup, current, candidate-`.doc`, candidate-`.docx`
all rendered 14 pages, normalized text 7529 chars with **identical SHA-256**
(`463f10cde73ab833937b3696ded693ad14685a3983576a7b204deba7fef12add`), and first-page AE was **0** for
all three candidates. Those numbers were true — and the user still saw broken glyphs in WPS on a
different revision. **Text hashes and same-engine pixels are necessary, not sufficient.** Compare
*all* pages (`scripts/verify_render_fidelity.sh`), not just page 1, and put the real deliverable in
front of the user's eyes before submission.

## 5. Stop-loss (learned the expensive way)

The chase above — LibreOffice variants, four candidate files, repeated render/compare rounds —
consumed roughly **20% of a metered Codex subscription quota**, and the user's own solution
(replace the compressed images in their original file in WPS, then submit) took them seconds and
was accepted. Order of operations that would have avoided it:

1. Measure, back up, hash-verify. (Always.)
2. Produce good compressed images — that part was never the problem.
3. **Offer the zero-risk paths first**: user re-saves in WPS; or user swaps the images in their
   original `.doc`.
4. Only if the user wants full automation, attempt the container work — with a cap of one or two
   attempts.
5. If fidelity breaks once, stop and hand back the images plus the two manual options.

When usage is metered, say the trade-off out loud *before* spending it, and prefer the route that
takes the user ten seconds over the one that takes you twenty tool calls.
