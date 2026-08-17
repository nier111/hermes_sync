---
name: hermes-desktop-linux
description: "Hermes desktop on Linux: build/launch/sandbox/entry fixes."
---

# Hermes desktop on Linux

## Trigger
- `hermes desktop` / `hermes gui` won't open, "downloads again" every launch,
  or the app-menu / wofi-drun launcher entry is dead
- After `hermes update` pulls new source, the desktop app may need a rebuild

## Build/launch mechanics (hermes_cli/main.py cmd_gui)
- Non-source mode: workspace `npm ci` → `npm run pack` (vite build +
  electron-builder --dir) → launch `apps/desktop/release/linux-unpacked/Hermes`
- `_desktop_build_needed` skips ONLY when the packaged executable exists AND
  `~/.hermes/desktop-build-stamp.json` contentHash matches the source. First
  successful CLI launch writes the stamp; until then EVERY launch rebuilds
  (user sees "it's downloading again").
- `hermes desktop --build-only` builds + writes stamp + exits WITHOUT launching —
  the headless way to verify/prepare a build (no display needed).
- Every successful launch re-registers the .desktop entry
  (~/.local/share/applications/hermes.desktop) — so a manual .desktop edit gets
  overwritten; fix the generator, not the file.

## Linux failure modes (check in this order)
1. chrome-sandbox not SUID → Electron aborts instantly; `hermes desktop` may
   exit 1 silently (no message when AppArmor userns restriction is absent).
   Fix: `sudo chown root:root <release>/linux-unpacked/chrome-sandbox &&
   sudo chmod 4755 <release>/linux-unpacked/chrome-sandbox`.
   RESETS on every rebuild. The CLI auto-fixes via sudo but fails when sudo
   needs a password in a launcher/non-interactive context.
2. Desktop entry Exec must NOT be the in-repo `hermes` script
   (`$HERMES_HOME/hermes-agent/hermes`). Its `#!/usr/bin/env python3` shebang
   resolves to SYSTEM python in launcher env (PATH lacks the venv) → crash on
   venv-only imports (e.g. pathspec). Exec must point at the PATH-independent
   venv wrapper (~/.local/bin/hermes). Upstream bug: resolve_exec_command()
   used argv[0], which inside the wrapper's exec chain is the repo script;
   patch `hermes_cli/linux_desktop_entry.py` to prefer
   `Path.home()/".local"/"bin"/"hermes"`. PATCH RESETS ON `hermes update`
   (repo reset to remote).
3. node-pty compiles from source on Linux — see cn-npm-mirror-setup.
4. Replicate the real launcher path: `gio launch ~/.local/share/applications/hermes.desktop`
   (wofi/GTK launch via GIO). Also test with a stripped env:
   `env -i HOME=$HOME PATH=/usr/local/bin:/usr/bin:/bin DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 <exec>`.
5. The hermes-bots desktop plugin auto-creates a per-profile 'Bot Chat' and
   sends kickoff "Hey, tell me about yourself!" — desktop sessions whose first
   user message is exactly that are auto-generated, NOT user messages. Don't
   attribute them to the user.
6. Benign noise (ignore): vaInitialize failed (no VA-API), all_proxy parse
   error (socks5:// scheme), dbus scope "already loaded", fontconfig cache
   version warning, DEP0180 fs.Stats deprecation.

## Wayland / Hyprland
- App needs DISPLAY/WAYLAND_DISPLAY; agent sessions that share the user's
  session env can launch it. grim screenshots for debugging need the same env
  (execute_code sandbox may lack them — screenshot via terminal, process via code).
