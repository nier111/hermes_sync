# WPS Office + Fcitx5 on Arch/Wayland

Use when Fcitx5 switches to Chinese but WPS still types ASCII.

## Diagnose before changing anything

1. Confirm packages and IM state:
   ```bash
   pacman -Q | grep -E '^(wps-office|fcitx5|fcitx5-qt)'
   fcitx5-remote
   ```
   `2` means Fcitx is active, not that the target app loaded the Qt IM module.
2. Inspect the live WPS process environment:
   ```bash
   pid=$(pgrep -n -f '/usr/lib/office6/(wps|wpsoffice|et|wpp)')
   tr '\0' '\n' < /proc/$pid/environ | grep -E '^(QT_IM_MODULE|XMODIFIERS|WAYLAND_DISPLAY|DISPLAY)='
   ```
3. If `XMODIFIERS=@im=fcitx` exists but `QT_IM_MODULE` is absent, the WPS private Qt runtime is not loading Fcitx despite `fcitx5-qt` being installed.

## Preferred fix: app-scoped launcher override

Avoid setting `QT_IM_MODULE=fcitx` globally on mixed Qt5/Qt6 Wayland desktops unless deliberately testing the whole session. A WPS-only wrapper avoids affecting native Qt6 applications.

Create `~/.local/bin/wps-with-fcitx`:

```sh
#!/bin/sh
export QT_IM_MODULE=fcitx
exec "$@"
```

Make it executable, then shadow each WPS desktop file under `~/.local/share/applications/`. Preserve the original file and prepend the wrapper to `Exec=`:

```ini
Exec=/home/USER/.local/bin/wps-with-fcitx /usr/bin/wps %U
Exec=/home/USER/.local/bin/wps-with-fcitx /usr/bin/et %F
Exec=/home/USER/.local/bin/wps-with-fcitx /usr/bin/wpp %F
Exec=/home/USER/.local/bin/wps-with-fcitx /usr/bin/wpspdf %F
```

Typical source files are `/usr/share/applications/wps-office-*.desktop`. Copy all relevant entries to the user directory, modify only `Exec=`, then run:

```bash
update-desktop-database ~/.local/share/applications
```

## Verification

- Wrapper seam test:
  ```bash
  ~/.local/bin/wps-with-fcitx /bin/sh -c 'test "$QT_IM_MODULE" = fcitx'
  ```
- Validate desktop entries with `desktop-file-validate` (category hints from upstream are non-fatal).
- Save documents and fully terminate old WPS processes before reopening; existing processes cannot gain new environment variables.
- Reopen from the application menu, then inspect `/proc/<new-pid>/environ` and test composition in a document.

## Why this happens

WPS ships a private Qt runtime. On a minimal Hyprland session, `XMODIFIERS` may cover X11 clients while WPS still requires the Qt IM module selector. This is WPS/private-Qt + mixed Wayland/XWayland integration, not evidence that Fcitx itself is broken.