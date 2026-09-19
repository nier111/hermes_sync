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
- The npmmirror registry does NOT cover the electron BINARY download, so a build
  can look "hung" while every npm fetch already succeeded: node_modules sits in
  the low MB with one ESTAB TCP to a GitHub IP growing by nothing for minutes.
  The mirror env vars must be in the environment of the process that RUNS the
  build — a build spawned as a child of another tool (e.g. `hermes update`
  triggering `desktop --build-only`) does not inherit your interactive shell's
  exports. Export them in the parent's environment, or run the build yourself.
- When that parent is a systemd unit (a gateway-launched update), no shell export
  can ever reach it: put the proxy in the unit itself — a drop-in with
  `EnvironmentFiles=` pointing at one shared env file, then `daemon-reload` and
  restart from an outside shell (see hermes-desktop-linux). Without that, every
  update re-stalls on the electron binary download.
- Tell stalled from merely slow with `du -sh node_modules` (bytes not moving) plus
  `ss -tnp | grep "pid=<node pid>"`; then kill children before parents.
