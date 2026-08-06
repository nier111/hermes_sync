---
name: vscode-code-oss
description: "VSCode/Code-OSS Linux: dirs, workbench, ext pitfalls."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [vscode, code-oss, extensions, workbench, linux]
---

# VSCode / Code-OSS on Linux

Handle VSCode-family editors on Arch/Linux: correct config & extension dirs, workbench.html patching (background/CSS-injection extensions), permission fixes, and extension pitfalls.

## Which build is installed? (Arch)

- `code` from Arch repos = **Code - OSS** (open-source build). Config dir `~/.config/Code - OSS/`, extensions `~/.vscode-oss/extensions/`. NOT `~/.config/Code/` or `~/.vscode/extensions/` (those are the proprietary build) — checking the wrong dir yields "no extensions installed" confusion.
- Binary lives at `/usr/lib/code/` (e.g. `/usr/lib/code/code.mjs` run under `/usr/lib/electron42/electron`).
- Verify which build a process is: `tr '\0' ' ' < /proc/<pid>/cmdline` shows `.../code.mjs`.

## workbench.html permission (EACCES on extensions that patch it)

Background/CSS-injection extensions (shalldie.background, Custom CSS and JS Loader) write to `/usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html`, which is root-owned → `EACCES: permission denied, access '...workbench.html'`.

Fix (user-level, persists until next `pacman -Syu` reinstalls code):

```bash
SUDO_ASKPASS=~/.hermes/askpass.sh sudo -A chown -R sato:sato /usr/lib/code/out/vs/code/electron-browser/workbench/
```

After a pacman update of `code`, re-run the chown. The extension re-injects its patch on next VSCode start (it detects the reverted file via checksums).

## shalldie.background pitfalls (verified 2026-08-06, v3.0.1)

- **`background.fullscreen` is broken on Linux**: its URL normalizer converts local paths to the `vscode-file://vscode-app/...` protocol and mangles them (path separators become backslashes: `vscode-file://vscode-app/home/sato/%5Chome%5Csato%5CPictures%5Cx.jpg`) → image never loads. No newer version fixes it (3.0.1 is latest on open-vsx & GitHub).
- **Workaround — "four sections, same image"**: configure `background.editor` / `.sidebar` / `.panel` / `.auxiliarybar` all with the same image; visually equivalent to full-window background (minor seams at region borders):
  ```json
  "background.editor": { "images": ["file:///home/sato/Pictures/ayane.jpg"], "opacity": 0.15, "size": "cover", "position": "center", "styles": [], "interval": 0, "random": false }
  ```
- **Config schema matters**: v3.x reads TOP-LEVEL `opacity` / `size` / `position` (NOT nested under `style`, and no `useFront` on fullscreen) — check the extension's own `readme.md` section table, not stale blog examples.
- A background extension patching workbench.html triggers the "installation appears to be corrupt" notice; shalldie injects CSS that hides it automatically — don't "fix" it by reinstalling.
- `file:///abs/path.jpg` in `images` works (section mode); plain absolute paths also work. `~` and `${ENV}` are expanded by the extension.

## Debugging an injected background

1. Verify the patch landed: `grep -oE "vscode-background-(start|end)" .../workbench.html`, check mtime (extension rewrites it on startup).
2. Inspect the generated image URL inside the injected script — a mangled URL (backslashes, `vscode-app` prefix on a user file) explains "image not showing" immediately.
3. Config written but nothing shows → compare your JSON against the plugin's `readme.md` field table (schema drift between versions is the usual culprit).
4. Extension source is a minified bundle: locate class implementation with a python `data.find('ClassName = class')` slice to read the real logic (selectors, URL normalization).

## General notes

- Extension list: `ls ~/.vscode-oss/extensions/`; disabled state lives in `~/.config/Code - OSS/User/settings.json` under `extensions.disabled`.
- After editing settings.json, a FULL restart of VSCode is required for activation-time extension re-patch (Reload Window is not always enough).
