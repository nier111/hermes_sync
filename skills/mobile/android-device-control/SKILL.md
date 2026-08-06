---
name: android-device-control
description: "Use when operating an Android phone via adb."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [android, adb, mobile, phone, screencap, device]
---

# Android Device Control (adb)

Operate an Android phone/tablet from the terminal via `adb`. Verified 2026-08-06 on a Huawei/Glory VNE-AN00 (Android 12) backup phone.

## Prerequisites / first-time setup

- `adb` comes from `android-sdk-platform-tools` (Arch) or `/opt/android-sdk/platform-tools`. Verify: `adb --version`.
- Phone side (one-time, by the user): Settings → About phone → tap Build number 7× (enables Developer options) → Developer options → **USB debugging** ON.
- Connect via USB cable; the phone shows an "Allow USB debugging?" dialog — user must tick "Always allow" and confirm.
- `adb devices -l` must show `device` state (not `unauthorized`). If `unauthorized`, the user needs to re-confirm on the phone (unlock screen first — a locked screen blocks the dialog).

## Core operations (all verified)

```bash
adb devices -l                          # connection + auth state
adb shell getprop ro.product.model      # device model
adb shell getprop ro.build.version.release
adb shell dumpsys battery | grep -E "level|status|temperature"   # battery (level may be stale cache)
adb shell df -h /data | tail -1         # storage
adb shell pm list packages | wc -l      # installed app count
adb shell wm size                       # screen resolution
adb shell dumpsys power | grep mWakefulness   # screen on/off
adb shell input tap X Y                 # simulate tap (after `wm size` / screenshot to locate)
adb shell input text "hello"            # type text
adb shell input keyevent KEYCODE_HOME   # e.g. 3=HOME, 4=BACK
adb install app.apk                     # install
adb shell pm uninstall -k --user 0 com.pkg   # uninstall (system app)
adb logcat -d | tail -50                # recent logs
```

## Screenshot + local-vision inspection workflow

The canonical way to "see" the phone from the agent (verified working):

```bash
adb exec-out screencap -p > /tmp/phone-screen.png
```

Then inspect the PNG with a **local** vision model. Cloud vision APIs may be region-blocked (403 "model not available in your region"), so prefer local ollama:

```bash
python3 - <<'EOF'
import base64, json, urllib.request
img = base64.b64encode(open('/tmp/phone-screen.png','rb').read()).decode()
req = urllib.request.Request('http://127.0.0.1:11434/api/generate',
    data=json.dumps({"model":"qwen2.5vl:3b","prompt":"描述这张安卓截图的内容","images":[img],"stream":False}).encode(),
    headers={'Content-Type':'application/json'})
print(json.load(urllib.request.urlopen(req, timeout=180)).get('response',''))
EOF
```

Loop: screenshot → describe → `input tap` → screenshot again = blind remote control of the phone.

## UI automation: find elements, tap precisely

```bash
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml
```

Parse `<node ... bounds="[x1,y1][x2,y2]" class="...">` to get button/input-field coordinates, then `input tap <cx> <cy>`.

**Coordinate-space gotcha (verified 2026-08)**: uiautomator bounds can be in LOGICAL px (e.g. width ~1600) while the physical panel is smaller (e.g. 720 wide — `wm size` shows physical). `adb shell input tap` takes PHYSICAL coordinates. If bounds numbers are larger than the physical panel, scale: `physical = logical × physical_width / logical_width`. When in doubt, iterate blind: tap an estimated physical point → screenshot → describe → adjust.

## adb reverse: phone → PC services over USB

```bash
adb reverse tcp:5900 tcp:5900
```

Makes the phone reach the PC's `localhost:5900` through the USB cable — **no WiFi needed** (survives dorm network cuts 00:00–06:30). Re-set after any adb server restart. Essential for pointing a phone app at a PC-hosted service (VNC, web server, etc.). See `references/phone-as-secondary-display.md` for a full worked example (phone as a second monitor).

## Pitfalls

- **Locked screen blocks everything**: authorization dialogs, input, even screencap may return a black/lockscreen image. Ask the user to unlock before remote work.
- **`dumpsys battery` `level: 0` can be a stale cache** even when the phone is on and charging — cross-check with `dumpsys power` wakefulness or the UI before alarming the user.
- **USB connection does NOT depend on WiFi** — works through dorm network cuts (00:00–06:30) as long as the cable is in.
- Wireless alternative: `adb pair` (needs same WiFi + pairing code) — only when WiFi is up; USB is the stable default.
- `adb exec-out screencap -p > file.png` (not `adb shell screencap`) avoids CRLF corruption of the PNG on some devices.
