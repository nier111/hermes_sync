# Hermes Desktop on Linux: launch, sandbox, launcher entry, theme

Companion to `references/hermes-desktop-cn-build.md` (CN build flow). This file covers what happens AFTER the build: why the packaged Electron app silently fails to launch, and how the desktop entry must be written.

## chrome-sandbox SUID (Electron on Linux)
- `apps/desktop/release/linux-unpacked/chrome-sandbox` must be owned root:root mode 4755 or Electron aborts instantly.
- `hermes desktop` auto-fixes it via `sudo chown root:root && chmod 4755`; when sudo fails (non-interactive / launcher context) it exits SILENTLY — exit 1, no message, no window. Symptom: `hermes desktop` works in a terminal, but a drun/wofi click does nothing and leaves no process.
- Manual fix on this box (note: the terminal wrapper may inject `-S`, which conflicts with `-A` — call `/usr/bin/sudo` directly):
  `SUDO_ASKPASS=~/.hermes/askpass.sh /usr/bin/sudo -A chown root:root <release>/linux-unpacked/chrome-sandbox`
  `SUDO_ASKPASS=~/.hermes/askpass.sh /usr/bin/sudo -A chmod 4755 <release>/linux-unpacked/chrome-sandbox`
- Any repack (`hermes desktop --build-only`, update rebuild) resets the SUID bit — re-apply after every repack.

## Launcher entry (.desktop Exec) must be PATH-independent — and the re-registration hazard
- EVERY successful `hermes desktop` launch re-registers `~/.local/share/applications/hermes.desktop` (`install_desktop_entry()`), so whatever Exec it writes must be launchable from a stripped-down launcher env (PATH=/usr/local/bin:/usr/bin:/bin, no venv, no nvm).
- BROKEN: Exec=`<repo>/hermes desktop`. That in-repo script's `#!/usr/bin/env python3` shebang resolves to SYSTEM python in the launcher env → `ModuleNotFoundError: No module named 'pathspec'` → silent crash (no window, no log entry).
- CORRECT: Exec=`~/.local/bin/hermes desktop` (install.sh venv wrapper — execs venv python by absolute path) or `<repo>/venv/bin/python -m hermes_cli.main desktop`.
- Patch applied to `hermes_cli/linux_desktop_entry.py`: `resolve_exec_command()` uses `_find_venv_launcher()` = `Path.home()/".local/bin/hermes"` when it exists, else `sys.executable -m hermes_cli.main`. Do NOT "fix" by consulting PATH or argv[0]: in the launcher env PATH has no hermes, and argv[0] (inside the wrapper's exec chain) IS the in-repo script — either choice re-writes the entry broken, and the next launch re-registers it, silently undoing a manual .desktop edit (this bit us once: a first shutil.which()-based patch was reverted by our own test launch).
- Verification that catches the rewrite hazard: `gio launch ~/.local/share/applications/hermes.desktop` (same GIO path wofi/GTK launchers use), wait ~15s, then check BOTH `pgrep -fc 'linux-unpacked/Hermes'` (expect 5+ alive) AND `grep ^Exec= ~/.local/share/applications/hermes.desktop` (must STILL be the wrapper path — a successful launch re-registers the entry).
- `desktop-file-validate` passes on both good and broken files — it does not catch the python-interpreter problem.
- This machine: Hyprland; the launcher is `wofi --show drun` (Mod+A); `$menu = hyprlauncher` (Mod+R) is NOT installed (unrelated broken keybind).
- Source patches to ~/.hermes/hermes-agent are reset by `hermes update` (git reset to match remote) — re-apply after updates.

## Desktop app theme: light/dark mode vs skins
- The desktop app defaults to LIGHT mode (`~/.config/Hermes/native-theme.json` → `"themeSource": "light"`). In light mode a dark skin (e.g. summer-night, background `#0b1026`) is SYNTHESIZED into a light palette → pure-white UI even though `display.skin` is set. This is the usual "desktop looks plain white" cause, not a broken skin.
- Fix in-app: `Shift+X` toggles light/dark (default keybind `appearance.toggleMode`); mode is persisted per-profile in the app's localStorage, so it sticks.
- Skins are shared across CLI/TUI/desktop; if the palette still looks wrong after dark mode, pick the skin in the Appearance panel / Cmd-K.

## Desktop sessions vs CLI resume (state.db source filter)
- The Electron desktop app writes sessions with `source='desktop'` into the SAME `~/.hermes/state.db` as CLI/TUI sessions; they appear in `hermes sessions list`.
- BUT `hermes -c` / `--continue` / `--resume latest` only resolves `source='cli'|'tui'` (`_resolve_last_session(source=...)`) — it will never auto-continue a desktop session, which users read as "client chat didn't sync to terminal". Open it explicitly: `hermes --resume <session-id>` (direct ID works regardless of source).
- "Hey, tell me about yourself!" in a desktop session is NOT a user message: the bundled hermes-bots desktop plugin sends it as the canonical bot-chat kickoff (`apps/desktop/src/plugins/hermes-bots/plugin.js` — "the gateway prunes zero-message sessions, so the chat is born with the bot introducing itself"). Each bot/profile gets ONE pinned forever-chat created this way, with a stored-session pin in bot meta.
