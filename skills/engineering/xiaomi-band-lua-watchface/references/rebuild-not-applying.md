# A rebuilt watchface may not replace the face the band is running

Status: **OPEN / unresolved.** Do not read this file as a fix. It records what
was verified, what was ruled out, and the diagnostic that a future session must
run first.

Observed 2026-09 on Xiaomi Smart Band 10 (firmware 3.1.16), install path =
Notify for Xiaomi (`com.mc.xiaomi1`) → 设备 → 设备工具 → 更新表盘.

## Symptom

The app reported `升级完成` — twice — while the band kept executing the
**previously** installed Lua:

- the timer still showed the old default (25:00) instead of the new one (50:00),
- the text was still the old non-ASCII set (boxes), not the new ASCII set,
- the face's own state file was still the old one with the old value in it.

So the phone-side status string is not evidence that the band's copy changed.

## What was verified

- **`升级完成` is only the app's report.** It can appear even when the band's
  running face is unchanged. Always confirm on the band itself.
- **The watchface ID cannot be changed from the compiler CLI.** The trailing
  numeric argument (`1461256429`) is inert: builds with `1461256429` and
  `2000000001` produced **byte-identical** `.bin` files (same size, same
  sha256). The `.info` sidecar carried the same ID for a community face and for
  an unrelated project, i.e. it is a fixed default. Consequence: every rebuild
  of a face is offered to the band under the same ID, and the app has an
  `watchface_error_alreadyinstalled` / *"This watchface may be already
  installed"* path for exactly that situation.
- **No byte-level evidence is available from the phone.** `adb logcat` contained
  no `com.mc.xiaomi1` upload/transfer/watchface lines for the session, so there
  is no local proof of how much (if anything) was written. The band's display is
  the only observable.

## Diagnostic to run first (cheap, non-destructive)

The set ships two different values, so the band's own reading tells you which
code is live:

```text
band shows 25:00  -> the previous face is still running (file not replaced,
                     or replaced but the running Lua was never reloaded)
band shows 50:00  -> the new code IS live, and the problem lies elsewhere
                     (e.g. glyph coverage), not in the upload
```

Then, to separate *not written* from *written but not reloaded*, observe the
band after a reload trigger that does not touch storage: switch to another
watchface and back, or reboot the band. If the marker changes afterwards, the
file was already on the band and only the running instance was stale. If it does
not, the file never landed.

## Unverified candidates — NOT tested, do NOT present as a fix

Recorded only so the next session does not re-derive them from scratch; each
needs its own verification before being recommended:

- clearing the band's existing uploaded watchface(s) before re-uploading, so the
  same-ID slot cannot be treated as "already installed",
- building to a different output filename (the ID is fixed, so this is expected
  to change nothing — the filename only affects the parser's file picker).

## Standing practice this produced

**Bake a human-readable version marker into every device build.** Any
upload-to-hardware step needs a value the user can read off the device at a
glance — a changed default, a label, a colour — because host-side tooling can
report success for a write that did not take effect. Add it *before* the first
upload, not after the mismatch appears.
