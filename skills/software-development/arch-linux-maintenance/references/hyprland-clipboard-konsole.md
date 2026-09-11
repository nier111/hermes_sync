# Hyprland clipboard history and consistent copy/paste keys

Use for a Hyprland/Wayland desktop where basic cross-app copy/paste works, but clipboard history is absent, terminal copy/paste differs from GUI apps, or Konsole selection highlighting is hard to see.

## 1. Establish the live architecture

Check the active configuration provider before editing anything:

```bash
hyprctl systeminfo | grep configProvider
```

When it reports `configProvider: lua`, edit `~/.config/hypr/hyprland.lua`; changing a stale `hyprland.conf` can appear successful while doing nothing. Verify changes with:

```bash
Hyprland --verify-config --config ~/.config/hypr/hyprland.lua
hyprctl reload
hyprctl configerrors
hyprctl binds -j
```

Basic Wayland clipboard transfer does not prove a history manager is active. Check both packages and processes. `wl-clipboard` only provides `wl-copy`/`wl-paste`; `cliphist` records nothing without watcher processes.

## 2. Enable cliphist for text and images

In a Lua autostart block:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
```

For the current already-running session, start equivalent transient user services so they survive the agent shell but do not duplicate next-login autostart:

```bash
systemd-run --user --unit=cliphist-text --property=Restart=on-failure --collect \
  /usr/bin/wl-paste --type text --watch /usr/bin/cliphist store
systemd-run --user --unit=cliphist-image --property=Restart=on-failure --collect \
  /usr/bin/wl-paste --type image --watch /usr/bin/cliphist store
```

Verify both units are active. Test the database without overwriting the user's clipboard: pipe a unique token directly into `cliphist store`, confirm it appears in `cliphist list`, decode it, then delete that exact test row.

A safe Wofi picker writes the chosen historical item back to the clipboard but does not auto-paste it into the focused application:

```bash
#!/usr/bin/env bash
set -o pipefail
selection=$(cliphist list | wofi --dmenu --prompt '剪贴板历史' --insensitive)
[[ -n "$selection" ]] || exit 0
printf '%s' "$selection" | cliphist decode | wl-copy
```

Bind it to an unused key such as `SUPER+SHIFT+V`; preserve an existing `SUPER+V` window-management bind. Prefer an explicit executable path in the Lua binding and verify the picker process really starts. The user then selects an item, presses Enter, and pastes normally.

## 3. Consistent Ctrl+Shift+C/V without breaking terminals

Do not globally translate `Ctrl+Shift+C` into `Ctrl+C` unconditionally: in a terminal, `Ctrl+C` is SIGINT. Also explain that GUI applications may already use `Ctrl+Shift+C` for inspect-element and `Ctrl+Shift+V` for paste-without-formatting; get the user's explicit choice before overriding those actions.

A low-latency Lua conditional keeps terminal-native shortcuts while making the shifted variants aliases elsewhere:

```lua
local terminalClasses = {
    ["konsole"] = true,
    ["org.kde.konsole"] = true,
    ["kitty"] = true,
    ["foot"] = true,
    ["alacritty"] = true,
    ["wezterm"] = true,
    ["org.wezfurlong.wezterm"] = true,
}

local function clipboardAlias(key)
    return function()
        local window = hl.get_active_window()
        if window == nil then return end
        local class = string.lower(window.class or "")
        local mods = terminalClasses[class] and "CTRL SHIFT" or "CTRL"
        hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = key, window = window }))
    end
end

hl.bind("CTRL + SHIFT + C", clipboardAlias("C"))
hl.bind("CTRL + SHIFT + V", clipboardAlias("V"))
```

Leave ordinary `Ctrl+C/V` unbound so applications retain their standard behavior. After reload, confirm the bindings appear in `hyprctl binds -j`, then have the user test in a harmless browser/editor field and separately in the terminal; never inject the test sequence into an active command shell.

## 4. Konsole selection visibility

Konsole's selection visibility is a profile property, not an arbitrary `SelectionBackground`/`SelectionForeground` section in a `.colorscheme`. Persist this in the active profile:

```ini
[Appearance]
InvertSelectionColors=true
```

For the current tab, Konsole's `konsoleprofile` mechanism emits OSC 50:

```text
ESC ] 50 ; InvertSelectionColors=true BEL
```

Send it only to the intended Konsole tab and verify visually with the user. This makes selected text use inverted foreground/background colors and is especially useful with wallpaper-backed or low-contrast schemes.

## Verification checklist

- Active provider and edited file match.
- Hyprland native config verification returns `config ok`.
- `hyprctl configerrors` is empty after reload.
- Text and image watcher processes are active.
- cliphist store/list/decode/delete round-trip passes and test data is cleaned.
- `SUPER+SHIFT+V` opens the picker and selecting an item updates the clipboard.
- Shifted copy/paste aliases work in a GUI app and remain native in Konsole.
- Konsole selection is visibly distinct after enabling inversion.
