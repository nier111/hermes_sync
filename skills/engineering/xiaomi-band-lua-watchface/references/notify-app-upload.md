# Installing a custom watchface with Notify for Xiaomi

Verified 2026-09 with `com.mc.xiaomi1` 23.6.4 (APKMirror, arm64-v8a + v7a,
160-640dpi bundle) on an HONOR VNE-AN00 / Android 12 side-phone against a
Xiaomi Smart Band 10. The stock Mi Fitness app is **not** required.

## Why this app

It is the practical sideload path for `.bin` watchfaces (and `.rpk` apps) and it
does not need the phone's Play/Google services — relevant on CN ROMs without a
VPN. Install as a split-APK bundle:

```sh
adb install-multiple -r base.apk split_config.arm64_v8a.apk \
    split_config.zh.apk split_config.xxhdpi.apk
```

(OEM bundle picker may ask twice; keep the bundle and the device's ABI/density
splits only.)

## Permission prerequisites — the #1 "it can't see my band" cause

A band already bonded in system Bluetooth is invisible to the app until its
runtime permissions are granted. Grant only these three; do not blanket-grant
contacts/SMS/camera:

```sh
adb shell pm grant com.mc.xiaomi1 android.permission.BLUETOOTH_SCAN
adb shell pm grant com.mc.xiaomi1 android.permission.BLUETOOTH_CONNECT
adb shell pm grant com.mc.xiaomi1 android.permission.ACCESS_FINE_LOCATION
adb shell cmd appops get com.mc.xiaomi1     # verify
```

After granting, force-stop and relaunch the app; it then finds the bonded band
and advances past the "choose your device" step.

## Pairing key (authkey) — required for anything beyond a dead connection

Modern Xiaomi wearables use a one-time Bluetooth password. The app calls it
**Pairing key**; elsewhere **authkey** — same value.

- It is the **WearAuthV2 bind token** for that band, entered as hex.
- The input validator accepts **32-34 characters** (a 16-byte token hex-encodes
  to 32).
- Enter it in the app's own settings screen (`AuthKeyActivity`), which is
  reachable in-app; it is `exported=false`, so `adb shell am start` is refused —
  navigate the UI instead.
- The app also offers an online "get my key" flow that wants the Xiaomi account
  password on a third-party site. Avoid it: the token is already recoverable
  locally (see the `wearable-ble-re` skill), so the offline/manual path is both
  cheaper and does not hand credentials to a third party.

### Symptom table

| What you see | Meaning |
|---|---|
| Device not listed at all | BLE runtime permissions missing, or the band's system-Bluetooth link is stale |
| Listed, **battery 0%**, no watchface thumbnails | Connected at link level only — authkey missing/wrong |
| Battery % + watchface list populate | Authenticated; uploads will work |
| "Pause <official app>" warning | Another process holds the RFCOMM channel; on a phone without Mi Fitness this can be a system-Bluetooth manual connection |

## Upload flow (real UI ids)

1. Bottom nav `main_page_device` -> **设备**.
2. Scroll to **设备工具** -> `cardViewUploadWatchface` ("更新表盘").
3. File picker opens (`com.android.documentsui/.picker.PickActivity`).
   **It only lists `.bin` files** — a `.face` will not appear. Navigate to
   `Download` and pick the built file.
4. Back in `WatchfaceUploadActivity`:
   - `textViewStatus` shows `有效的表盘！` for a compatible package, or an
     incompatible/old-model error.
   - `buttonStartUpdate` ("安装") starts the transfer.
   - On success `textViewStatus` becomes `升级完成`.
5. The watch may keep showing its previous screen; the switch takes effect
   shortly after.

The app validates model compatibility before upload, but its own warning notes
that a wrong-model watchface can brick the band.

## Ad-row hijack

`WatchfaceUploadActivity` renders an ad/upsell block between the status text and
the install button. With the phone online, a tap intended for **安装** can land
on the ad and launch a browser or an app-store update prompt instead.

Workaround that was verified: turn the phone's Wi-Fi and mobile data **off**
for the duration of the upload (Bluetooth is what carries the payload, and the
file is local), then restore:

```sh
adb shell svc wifi disable ; adb shell svc data disable
# ... upload ...
adb shell svc wifi enable  ; adb shell svc data enable
```

Also force-stop any messenger that may hold the foreground (WeChat/QQ webviews
steal focus and your taps silently go to the wrong app).

## Driving the phone reliably

Locate elements by id/text from a fresh `uiautomator dump` each step rather than
remembering pixels — pages shift as banners and consent dialogs appear. If a
required button seems missing, re-dump: OEM consent flows add extra pages
("继续" -> "了解更多" -> tick the checkbox -> "继续安装").

Other device-side gotchas:

- `cmd package resolve-activity --brief` can print extra lines
  (`priority=0 preferredOrder=0 ...`) that break `am start -n "$VAR"`; parse the
  last line or pass the explicit `pkg/.Activity`.
- Force the app to the foreground with `am start -n <pkg>/<activity>` after any
  other app grabbed focus; `am start` alone may just raise another task.
- A landscape-locked phone hides bottom buttons in full-screen wizards; lock
  portrait temporarily and restore `accelerometer_rotation` afterwards.
