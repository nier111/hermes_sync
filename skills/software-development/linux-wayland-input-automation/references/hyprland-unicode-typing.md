# Hyprland Unicode Foreground Typing Reference

This reference records a validated pattern for a user-run foreground typing utility on native Wayland Hyprland. It is intentionally backend-focused and not tied to a particular website.

## Validated environment shape

- Wayland session with Hyprland
- Native Wayland Chromium and a Tk/XWayland receiver both tested
- Fcitx5 available as the input method
- `ydotoold` running with a user-accessible socket
- the user has read/write access to `/dev/uinput`

Re-check these facts live; they are prerequisites, not universal defaults.

## Why common approaches diverge

### Windows source ports

Windows implementations using `ctypes.windll.user32`, `SendInput`, `RegisterHotKey`, virtual-key codes, and a Win32 message loop are not portable abstractions. Preserve GUI/business logic only; replace the input and hotkey layers.

### `pynput` on Wayland

A successful `pynput` import does not mean native Wayland clients are controllable. Its Xorg backend can work for XWayland targets while native Wayland applications receive nothing.

### Dynamic-keymap virtual keyboards

On some Hyprland versions, a client that constructs a dynamic keymap can exit successfully while text is remapped into sequential digits or unrelated keys. A live reproduction observed a mixed string arrive as a sequence resembling `12314567890-\tq`. Similar public reports describe `Terra123` turning into digits.

This signature means the compositor accepted events but interpreted the temporary keymap incorrectly. Delays do not repair it. Use an evdev/uinput path that survives exact read-back.

## Validated pointer path

Capture:

```text
hyprctl cursorpos -j
```

Restore:

```text
hyprctl dispatch movecursor X Y
```

Click:

```text
ydotool click 0xC0
```

Use the compositor dispatcher for exact pointer restoration. `ydotool mousemove --absolute` warns that acceleration can affect positioning.

## Validated ASCII path

Stream text over stdin:

```text
ydotool type --key-delay 20 --file -
```

This avoids exposing a long document in argv. Raw ydotool text entry correctly handles ASCII and newline in the validated setup, but unsupported CJK characters are omitted because evdev has no physical keycodes for them.

## Validated non-ASCII compose sequence

For each non-ASCII code point:

1. Press Ctrl and Shift.
2. Press and release U.
3. Release Shift and Ctrl.
4. Type the lowercase hexadecimal Unicode code point.
5. Press and release Enter.

Evdev event sequence for Ctrl+Shift+U:

```text
29:1 42:1 22:1 22:0 42:0 29:0
```

Commit with Enter:

```text
28:1 28:0
```

Example for `中` (U+4E2D):

```text
ydotool key -d 1 29:1 42:1 22:1 22:0 42:0 29:0
ydotool type --key-delay 1 4e2d
ydotool key -d 1 28:1 28:0
```

Use a short internal delay such as 1 ms for the compose mechanics, then sleep for the user-selected character interval after the character is committed. Buffer adjacent ASCII into a single stdin-driven `ydotool type` call; flush that buffer around every non-ASCII character.

This sequence depends on a working Unicode compose facility in the active input method/toolkit. Verify it in the actual target before adopting it.

## Controlled receiver recipe

Build a harmless GUI receiver with these properties:

- unique window title
- one focused multiline text widget
- expected mixed fixture supplied through environment or test configuration
- exact observed value written as JSON to a temporary path
- automatic timeout and clean exit

Driver sequence:

1. Remove stale result data.
2. Launch receiver.
3. Poll compositor clients until the unique window appears.
4. Compute a point inside its geometry.
5. Focus the exact window address.
6. Move cursor to the point.
7. Run the production CLI, not a copied experimental helper.
8. Wait with timeout.
9. Compare exact received value.

A validated fixture was:

```text
Wayland中文Test
第二行
```

The receiver read it back exactly.

## Native Chromium verification

A browser-specific claim needs a native browser test:

1. Open a harmless page containing a textarea.
2. Give the textarea a real pointer click; do not rely only on JavaScript focus.
3. If the browser is on another workspace, save the current workspace.
4. Switch to the browser workspace.
5. Focus the exact compositor window address.
6. Re-read the compositor active window and abort unless it matches.
7. Type through the production program.
8. Restore the original workspace in a `finally` path.
9. Read `textarea.value` from the page and compare exactly.

A native Wayland Chromium test read back:

```text
Chromium中文Test
第二行
```

A prior attempt that focused only the DOM and did not establish real page-content/native focus received an empty value. The durable lesson is to verify both focus layers, not that browser input is unsupported.

## Safety notes

- Never aim integration tests at a submit, delete, purchase, or send control.
- Never inject into the user's active terminal; a newline can execute text as a command.
- Save and restore workspaces around visible focus tests.
- Include a dry-run that performs no pointer or keyboard mutation.
- Prefer a local file for long user text and keep a backup before automating consequential forms.
