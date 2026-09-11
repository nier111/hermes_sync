# Arch desktop app integration: WPS/Fcitx and Electron hangs

Use this for proprietary desktop apps on Hyprland/Wayland when the symptom is app-specific input failure or an Electron window marked “Not responding.” Keep fixes app-scoped where possible.

## WPS Office + Fcitx5: Chinese mode but English text

### Evidence chain

Before changing anything, verify all boundaries:

1. Packages: WPS plus `fcitx5`, `fcitx5-qt`, the desired engine, and config tool are installed.
2. `fcitx5-remote` returns `2` while Chinese mode is selected.
3. Inspect the live WPS process environment through `/proc/<pid>/environ`.
4. If `XMODIFIERS=@im=fcitx` exists but `QT_IM_MODULE` is absent, and WPS's launcher does not export it, the private Qt runtime is not loading the Fcitx input module.

### App-scoped fix

Avoid setting global Qt variables merely for WPS; global `QT_IM_MODULE` can affect unrelated Wayland Qt applications.

Create an executable wrapper such as:

```sh
#!/bin/sh
export QT_IM_MODULE=fcitx
exec "$@"
```

Then copy the WPS desktop entries from `/usr/share/applications/` to `~/.local/share/applications/` and prefix each `Exec=` target with the wrapper. Cover Writer, Spreadsheets, Presentation, PDF, and the combined WPS launcher. Validate with `desktop-file-validate`, rebuild the user MIME/desktop cache, and prove the wrapper exports the variable with a shell assertion.

The already-running WPS process keeps its old environment. Do not kill it while documents may be unsaved; tell the user to save and fully exit WPS before reopening from the application launcher. WPS can retain background processes after windows close, so verify process exit if the fix appears not to apply.

## Electron desktop app “Not responding” after file send

### Capture the hang before restarting

Gather a compact snapshot first:

- main/child process tree and thread wait states;
- RSS, CPU, available memory/swap, disk and `/tmp` space;
- recent kernel OOM/GPU/segfault messages;
- app launcher logs and Crashpad/coredump evidence;
- exact app and embedded Electron versions;
- config/cache/database sizes.

A sleeping event-loop main process with living children, no coredump, no OOM, and a compositor “not responding” window indicates a hang rather than a crash or resource exhaustion. Do not call low CPU alone the root cause.

After evidence capture, honor the user's preference to restore service promptly: terminate the full app process tree, verify it is gone, relaunch with the existing desktop-entry flags, and verify a newly mapped compositor window plus a new process tree. If a file send was in progress, warn against immediate duplicate sending until chat history confirms delivery state.

### Prefer version correction over cache deletion

Compare the installed package against the current AUR RPC result. If the app is several upstream/Electron releases behind and cache/database sizes are ordinary, upgrade before deleting user data. Preserve user-level desktop overrides across the package upgrade.

For AUR updates:

- A background `yay` build can successfully produce the package but fail at the final child `sudo` because no TTY is available.
- Treat that as an install-boundary issue, not a failed build. Verify source checksums/build success, then install the generated package in a foreground privileged `pacman -U` step instead of rebuilding.
- Stop Electron before replacing `/opt/<app>` so the live process cannot load a mixture of old and new files.
- Relaunch and verify the installed package version, Crashpad annotations/embedded Electron version, process tree, and mapped window.

Do not claim an exact file-upload function bug without a useful app log or reproducible trace. Report the evidence-supported conclusion: renderer/event-loop hang, resource exhaustion excluded, and stale-version correction applied. If it reproduces on the current version, compare drag/drop vs picker, small vs large files, and XWayland vs native Wayland while tracing renderer IPC/syscalls.
