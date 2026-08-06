---
name: vscode-oss-linux
description: "VSCode/Code-OSS on Arch: config dirs, injection perms."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [vscode, code-oss, arch, extensions, background, workbench]
---

# VS Code / Code - OSS on Linux (Arch)

Covers the Arch Linux `code` package (which is **Code - OSS**), its config/extension layout, and the class of extensions that inject into `workbench.html` (shalldie.background, Custom CSS and JS Loader) — including the EACCES permission trap and config-format pitfalls.

## Directory map — OSS build vs Microsoft build (critical)

| Thing | Code - OSS (Arch `code`) | Microsoft VSCode |
|---|---|---|
| Extensions | `~/.vscode-oss/extensions/` | `~/.vscode/extensions/` |
| User settings | `~/.config/Code - OSS/User/settings.json` | `~/.config/Code/User/settings.json` |
| Install root | `/usr/lib/code/` | `/usr/lib/code/` (AUR bin build) |

Symptom "extension is installed but nothing happens / settings not applied" on Arch is almost always the agent grepping the WRONG dir (`~/.vscode/extensions` or `~/.config/Code` are empty on OSS). Check `~/.vscode-oss/` and `~/.config/Code - OSS/` first. The running binary is `/usr/lib/code/code.mjs` launched via `/usr/lib/electron42/electron`.

## File-injection extensions & the EACCES trap

Extensions like `shalldie.background` rewrite `/usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html`. That file is root-owned (`-rw-r--r-- root root`), so the plugin fails with:

```
EACCES: permission denied, access '/usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html'
```

Fix (on this machine use the askpass helper):
```bash
chmod +x ~/.hermes/askpass.sh   # once — it ships without +x
SUDO_ASKPASS=/home/sato/.hermes/askpass.sh sudo -A chown -R sato:sato /usr/lib/code/out/vs/code/electron-browser/workbench/
```
Then fully restart VSCode (kill the process; Reload Window is not always enough for injection plugins to re-apply).

**Pacman updates reset everything**: upgrading `code` restores root ownership AND resets workbench.html — the plugin silently stops working until you re-run the chown and restart VSCode (the plugin re-injects on next start). Re-runnable helper: `scripts/fix-workbench-perms.sh`.

The "installation appears to be corrupt. Please reinstall." toast after a restart is EXPECTED for injection plugins — shalldie.background injects CSS that hides that toast itself; harmless.

## shalldie.background v3 config (verified 3.0.1)

- Config keys live under `background.enabled` + per-section objects: `background.fullscreen` / `.editor` / `.sidebar` / `.panel` / `.auxiliarybar`.
- **Field layout is TOP-LEVEL**: `images`, `opacity` (0.1–0.3 recommended), `size` (`cover`), `position` (`center`), `styles` (array), `interval`, `random`. There is NO top-level `style` object and NO `useFront` on fullscreen — those are v1-era keys (`background.useFront`, `background.customImages`) that v3 ignores. Putting opacity/size/position inside a nested `style` object makes the plugin silently no-op.
- `images` accepts: absolute path `/home/x/Pictures/a.jpg`, `file:///abs/path`, `~/Pictures/a.png`, `${HOME}/...`, folders, https URLs, data URLs.
- **Single image across the whole window** = `background.fullscreen` with one image. Setting `background.editor` + `background.sidebar` separately tiles DIFFERENT images per pane — that's the "几个小窗口分别显示不同图片" trap.
- Known-good config: `templates/background-fullscreen.json`.
- The plugin's own `readme.md` (inside the extension dir) has the authoritative field tables; the user's KB example (`~/projects/HelpListCreatedByAyane/HelpListMD/Vscode/vscodeBackgroundProfile.md`) predates v3 and uses the outdated nested-`style` format — trust the readme, not old examples.

## Workflow

1. Identify build: `ls ~/.vscode-oss 2>/dev/null || ls ~/.vscode/extensions` — pick the dir map above.
2. For injection-extension EACCES: run the chown script, restart VSCode fully.
3. For "no background": check settings.json keys against v3 top-level layout; prefer fullscreen for one image; verify the image path with `file` (progressive JPEGs fine); confirm the injection marker exists in workbench.html (`grep vscode-background /usr/lib/code/out/vs/code/electron-browser/workbench/workbench.html`).
4. After any pacman `code` upgrade: re-chown + restart (add a reminder; ownership reset is silent).
