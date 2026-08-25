---
name: linux-wayland-input-automation
description: "Use when building foreground input automation on Wayland."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [linux, wayland, hyprland, uinput, keyboard, mouse, automation]
    related_skills: [computer-use, systematic-debugging, test-driven-development]
---

# Linux Wayland Input Automation

Use this skill when building or debugging a user-run program that deliberately sends foreground mouse or keyboard input under Wayland. Typical cases include text-entry helpers, accessibility utilities, macro tools, and migration of Windows `SendInput`/`RegisterHotKey` or X11 `pynput`/`xdotool` code.

This skill is about creating and validating an input utility. For agent-driven background desktop control that should not steal the user's focus, use `computer-use` instead.

## Core principles

1. Identify the live session and compositor before choosing a backend. Wayland deliberately prevents arbitrary clients from injecting input through the old X11 APIs.
2. Separate pointer placement, pointer clicking, ASCII typing, and Unicode text entry. A single tool may not implement all four correctly.
3. Treat command success only as transport success. The acceptance criterion is text read back from the real target widget.
4. Test against the target toolkit class. Passing in Tk/XWayland does not prove native Chromium/Wayland behavior.
5. Never test by typing into the user's current terminal, chat, or consequential form. Create a controlled receiver and verify focus before injection.
6. Keep an emergency stop path (`Ctrl+C`, cancellation event, or process termination) and add a countdown before foreground input.

## Discovery checklist

Before implementation, collect:

- `XDG_SESSION_TYPE` and `XDG_CURRENT_DESKTOP`
- compositor-native cursor and active-window state
- whether the target window is native Wayland or XWayland
- available input backends (`ydotool`, compositor dispatchers, protocol clients)
- `/dev/uinput` permission and daemon/socket readiness when using uinput
- active input method framework, especially Fcitx5 or IBus

Do not assume `pynput` support merely because imports succeed. On a Wayland session it may only control XWayland clients.

## Recommended architecture for Hyprland

Use small injectable components so pointer and keyboard behavior can be tested independently:

1. Capture the pointer using `hyprctl cursorpos -j`.
2. Restore exact coordinates with `hyprctl dispatch movecursor X Y` rather than absolute uinput motion, which may be distorted by acceleration.
3. Click with a uinput backend such as `ydotool click 0xC0`.
4. Send ASCII runs through `ydotool type --file -`, passing text over stdin rather than argv.
5. For non-ASCII characters, test the input method's Unicode compose path. With a validated Fcitx/Linux setup, emit `Ctrl+Shift+U`, the hexadecimal code point, then Enter.
6. Keep internal compose-event delays short; apply the user-facing interval between completed characters.

Read `references/hyprland-unicode-typing.md` for the validated event sequence, failure signatures, and integration-test recipe.

## Text-source interface

A reusable CLI should support:

- `--text` for short input
- `--file` for UTF-8 files and long documents
- stdin when neither is supplied
- `--delay` before input
- `--interval-ms` between characters
- `--no-click` when focus is already established
- `--dry-run` that reports coordinates and text length without injecting events

Prefer stdin or a file for long/sensitive text. Putting a document directly in argv exposes it through process listings and may hit shell argument limits.

## TDD seams

Wrap process execution behind an injectable command runner. Unit-test:

- UTF-8 source selection
- compositor cursor JSON parsing
- exact pointer restore and click commands
- ASCII buffering around non-ASCII characters
- Unicode compose event ordering
- empty input and invalid timing rejection

Then add a real integration receiver that:

1. Opens a harmless text widget.
2. Writes its observed value to a temporary result file.
3. Times out rather than hanging forever.
4. Is focused by verified window identity.
5. Receives a mixed fixture containing ASCII, CJK, and newline.
6. Compares exact read-back with the fixture.

Run a second integration test in a native Wayland Chromium textarea when the actual target is browser-based. Give page content a real pointer focus before injection; JavaScript `element.focus()` alone does not prove native keyboard focus entered the page.

## Failure analysis

### Command exits successfully but characters are wrong

This usually means events reached the compositor but were interpreted under a different keymap. Record the exact expected and received strings. A sequence such as `Terra123` becoming digits is a keymap-layer signature, not a random timing issue.

Do not keep changing delays. Compare the backend's keymap model with the compositor's handling and try a backend that emits stable evdev keycodes.

### ASCII works but CJK disappears

Raw evdev keycodes represent physical keys, not arbitrary Unicode. Preserve ASCII runs and use a validated input-method compose sequence for non-ASCII code points. Do not claim Unicode support until mixed text is read back exactly.

### DOM says an element is focused but native input is lost

DOM focus and Wayland/native window focus are separate layers. Verify the compositor's active window and perform a real page-content click. If the target is on a hidden workspace, switch to it temporarily, verify the exact active window address, test, and restore the original workspace.

## Safety and verification gate

Before reporting success, require all of the following:

- unit tests pass
- daemon/socket and uinput access are live when required
- pointer movement lands at the captured coordinates
- controlled native widget reads back exact mixed Unicode text
- native browser target reads back exact text when browser support is claimed
- no consequential button was clicked
- dry-run produces no input events
- generated cache/test artifacts are ignored or cleaned

Report actual received text and backend state, not merely exit code zero.

## Pitfalls

- Do not use the active user terminal as an input receiver; newlines can execute unintended commands.
- Do not infer browser focus from DOM `activeElement` alone.
- Do not treat a Tk/XWayland pass as proof for native Wayland Chromium.
- Do not pass long private text in process arguments when stdin is available.
- Do not use uinput absolute mouse movement for exact Hyprland coordinates when acceleration can alter the result.
- Do not encode a transient package-install failure as a permanent tool limitation.
- Do not preserve a backend only because it is popular; keep the backend that passes exact read-back on the live compositor.
