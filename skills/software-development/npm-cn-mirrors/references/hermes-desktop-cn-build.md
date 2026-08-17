# Hermes Desktop: CN build & launch (this machine)

Context: ~/.hermes/hermes-agent git install; desktop app source at apps/desktop (Electron 40.x, package.json engines node >=22.22.0; install.sh says Hermes requires Node >=26).

## Launch flow (what `hermes desktop` does)
1. Resolves npm from PATH (no Hermes-managed node on this box → falls back to PATH; if nvm is active in the shell, that is nvm's npm/node version!).
2. `_desktop_build_needed()` (packaged mode) returns True unless BOTH:
   - `apps/desktop/release/linux-unpacked/Hermes` exists
   - `~/.hermes/desktop-build-stamp.json` contentHash matches current source (stamp has `sourceMode: false`)
3. If needed: `npm ci` at repo root (workspace install; ~1300 pkgs incl. Electron + node-pty) → `npm run pack` (electron-builder `--dir --publish never`) → `_write_desktop_build_stamp()` → launch packaged exe.
4. Until ONE successful pack happens, EVERY `hermes desktop` re-runs npm ci + pack. A manual `npm run build` (or `npm ci`) does NOT write the CLI stamp — only the `hermes desktop` path does.

## Headless pre-build
`hermes desktop --build-only` — runs the full install + pack + stamp, verifies the artifact, does NOT launch the GUI. Use this when you cannot babysit a long build or want to pre-flight before telling the user to launch.

## Env needed on CN network (see parent skill npm-cn-mirrors)
- `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`
- `ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/`
- Shell proxy env (http_proxy=127.0.0.1:7890 etc.) helps node-gyp header downloads and any GitHub fetches; npm itself ignores proxy env unless `npm config set proxy`.

## Failure signatures seen on this machine
- update.log: `npm error code ECONNRESET ... ✓ ui-tui, web workspaces installed (desktop skipped)` — `hermes update` deliberately skips the desktop workspace (electron ~200MB); desktop must be built separately via `hermes desktop` or `hermes desktop --build-only`.
- npm log: `electron@40.10.2 postinstall ... signal SIGINT` — electron binary download interrupted (GitHub blocked/slow, or user Ctrl-C). Fix: ELECTRON_MIRROR + re-run.
- npm log: `node-pty@1.1.0 install ... Rebuilding because directory node_modules/node-pty/prebuilds/linux-x64 does not exist` then `node-gyp rebuild` then SIGINT — this is the NORMAL Linux source compile; user Ctrl-C'd. Do not interrupt; give it minutes.
- "Node.js v22.22.3 is too old (Hermes requires Node >=26)" — nvm default 22.22.3 in the user's zsh vs Hermes requirement. Fix: `nvm alias default system` (system node 26.5.1 via pacman). The packaged desktop launch itself does not need node, but rebuilds/updates from the user's shell do.

## Post-build verification
- `ls -la apps/desktop/release/linux-unpacked/Hermes` (≈200MB executable)
- `cat ~/.hermes/desktop-build-stamp.json` → `{"contentHash": ..., "sourceMode": false, "builtAt": ...}`
- Desktop launcher entry: `~/.local/share/applications/hermes.desktop`

## Wayland note
If the window is blank/black on a Wayland session, try ozone/GPU flags (same class of fix as the QQ desktop blur issue on this machine; config keys under `desktop.*`).
