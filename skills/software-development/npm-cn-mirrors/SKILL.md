---
name: npm-cn-mirrors
description: "Use when npm installs fail in China (ECONNRESET, mirrors)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [npm, node, mirror, china, network, electron, npmmirror, proxy, node-pty]
---

# npm on China / campus networks

## When to use
- `npm install` / `npm ci` very slow (30-47s per tarball), `ECONNRESET`, `network aborted`
- Electron / electron-builder binaries fail to download (GitHub releases blocked/slow)
- "engine incompatible / too old" confusion caused by node version mismatch
- Native module messages like "Rebuilding because directory ... does not exist"

## Fast fix (mirror, no proxy needed)
```bash
npm config set registry https://registry.npmmirror.com
npm config set replace-registry-host npmjs   # rewrites lockfile registry.npmjs.org URLs to the mirror
npm config set audit false
npm config set fund false
# verify — this should return well under 1s:
npm view semver version
```

## Electron & electron-builder binaries — env vars, NOT npm config
- `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/` — electron postinstall binary download
- `ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/` — app-builder-bin and friends
- npm 12 REJECTS `npm config set electron_mirror ...` ("not a valid npm option") — pass as env var: `ELECTRON_MIRROR=... npm ci`

## npm vs shell proxy env
- npm does NOT automatically use the shell's HTTP_PROXY/HTTPS_PROXY vars. Observed: env proxy set, yet tarball fetches still took 30-47s each.
- Either configure npm explicitly (`npm config set proxy http://127.0.0.1:<port>` + `https-proxy`), or — preferred on CN campus networks — point at npmmirror directly.

## Native modules that ALWAYS build from source on Linux
- node-pty's tarball ships prebuilds only for darwin/win32; on Linux `scripts/prebuild.js` just checks for `prebuilds/linux-x64`, finds none, and `node-gyp rebuild` runs.
- "Rebuilding because directory ... does not exist" is NORMAL, not an error. Needs gcc/g++/make/python3. Let it finish (a few minutes) — Ctrl-C mid-build leaves node_modules torn and wastes the compile.

## "npm warn deprecated ..." is noise
- `npm warn deprecated glob@7.2.3 / rimraf / npmlog / gauge ... not supported` — harmless transitive-dep warnings, appear on every install. Users may read them as "一堆库太老了". Not errors; ignore.

## Pitfalls
- Node version mismatch: project may require a newer node than the shell's nvm default (e.g. Hermes install.sh: "Node.js vX is too old (Hermes requires Node >=26)"). Fix: `nvm alias default system` (use pacman/system node) or `nvm install <major>`; old nvm versions stay available via `nvm use <ver>`.
- Repo-local `.npmrc` can carry `engine-strict=true` and `min-release-age=N` gates → unexpected EBADENGINE/ETARGET. Check `cat <repo>/.npmrc` before blaming the network.
- `~/.npmrc` is protected from the write_file tool → configure via `npm config set`, not by writing the file directly.
- Interrupted `npm ci` leaves a partial node_modules (empty prebuilds dir, missing electron dist). Re-run npm ci to repair; do not hand-patch.

## Support files
- references/hermes-desktop-cn-build.md — Hermes Desktop-specific build/launch flow on this machine (stamp mechanics, --build-only, failure signatures).
