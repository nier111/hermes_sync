---
name: cn-npm-mirror-setup
description: "npm slow/blocked in China; set npmmirror + electron mirrors."
---

# CN npm mirror setup

## Trigger
- npm install/ci slow (each tarball 10-50s), ECONNRESET / "network aborted"
- electron binary download fails or SIGINTs during postinstall
- Any Node project on a China/campus network behind the GFW

## Recognize the symptom
- 30-47s per tarball fetch + occasional ECONNRESET = npm going DIRECT to
  registry.npmjs.org. npm ignores HTTP_PROXY/HTTPS_PROXY env vars by default —
  shell proxy vars do NOT apply to npm fetches.
- electron postinstall SIGINT = @electron/get trying GitHub releases (blocked/slow in CN).

## Fix (one-time per machine, persisted in ~/.npmrc)
```
npm config set registry https://registry.npmmirror.com
npm config set replace-registry-host npmjs   # rewrites lockfile registry.npmjs.org URLs to the mirror
npm config set audit false
npm config set fund false
```
- ~/.npmrc is a PROTECTED file — use `npm config set`, NOT write_file.
- Electron binary mirror: npm 12 rejects `npm config set electron_mirror`
  ("not a valid npm option"). Must pass an env var on install/build commands:
  ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
- electron-builder binaries (app-builder-bin etc.):
  ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/

## Verification
`time npm view semver version` — was 30-47s direct; <1s via mirror.

## Pitfalls
- npmmirror is directly reachable in CN: no proxy config needed.
- node-pty on Linux ships NO prebuilt binary in its npm tarball (only darwin/win32)
  — it ALWAYS compiles from source via node-gyp. Expected, not an error; needs
  gcc/g++/make/python3 and takes minutes. Do NOT Ctrl-C it.
- `npm ci` wipes node_modules then reinstalls; interrupting mid-way leaves a
  partial tree (e.g. missing electron, missing node-pty prebuilds). Re-run to
  completion; "Re-building because directory ... does not exist" is the node-pty
  check failing, not corruption.
