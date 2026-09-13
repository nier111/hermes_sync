# Replacing an already-installed watchface on the band

Status: **CONFIRMED FIX** (2026-09, Xiaomi Smart Band 10, firmware 3.1.16).

> If `references/rebuild-not-applying.md` still says "OPEN / unresolved", this
> file is the newer answer — the cause was found and confirmed on hardware. Keep
> that file's diagnostic table: it is still the fastest first check when an
> upload appears to do nothing.

## The rule

**Delete the band's copy first, then upload the new build.** In the band's own
watchface manager, remove the previously installed custom face, then run the
installer.

## Why

The face is keyed by a **fixed watchface ID** that cannot be changed from the
compiler CLI: builds with `1461256429` and `2000000001` produced **byte-identical**
`.bin` files, and the `.info` sidecar shows the same ID for unrelated projects.
While the old copy is installed, the band treats the upload as already present
and keeps running the OLD Lua — while the app still reports `升级完成`.

The installer's own string table contains `watchface_error_alreadyinstalled` /
*"This watchface may be already installed"* for exactly this situation.

## Confirmation on hardware

After deleting the old face, the very next upload took effect immediately, and
the face has been updated repeatedly since with the same delete-then-upload
order. Before the delete, two consecutive uploads each reported `升级完成` while
the band kept running the previous Lua (old timer default, old non-ASCII text,
old state file).

## Tell the user before you delete

The face's `SCRIPT_PATH` state file lives in the face directory and is removed
with it, so task toggles reset and session counters return to zero. Feature
behaviour is unaffected. Say this up front rather than letting the user discover
it afterwards.

## What is *not* evidence

- `升级完成` — the app's own report; it can appear without the band's copy changing.
- `adb logcat` — no `com.mc.xiaomi1` upload / watchface / transfer lines are
  emitted, so there is no byte counter to check. The band's display is the only
  observable. Do not burn time hunting for one.
- Renaming the output file — the ID is fixed; the name only affects the
  installer's file picker.

## Prevent the confusion next time

Ship a value the user can read off the band at a glance (a changed default, a
label, a colour) in every device build, **before** the first upload. When a
reported "successful" upload changes nothing on the band, go straight to the
delete instead of re-reading the Lua.
