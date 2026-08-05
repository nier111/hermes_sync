---
name: linux-data-usage-forensics
description: "Find what ate bandwidth on Linux: sudden data spikes."
---

# Linux Data-Usage Forensics (what ate my bandwidth)

## When to use
- Sudden large data usage on mobile hotspot / metered connection ("4GB gone in an hour")
- Suspected background services (agents, auto-updaters, package managers) eating bandwidth
- Need to attribute traffic to a process and stop it

## Investigation steps
1. Interface totals: `cat /proc/net/dev` — per-interface RX/TX bytes; identify the active link and how much it pulled. If the link is freshly up (hotspot just connected), the counter IS the damage.
2. Top consumers: `ps aux --sort=-%cpu | head -20` and `--sort=-%mem` — look for node/pnpm/npm installs, git fetch, package managers (pacman/apt), browser processes, updater binaries.
3. Pin down suspects: `ls -l /proc/PID/cwd` + `cat /proc/PID/cmdline | tr '\0' ' '` — confirms which project/service and exact command.
4. Hidden triggers (the non-obvious part): `systemctl --user list-units` — TRANSIENT services created via `systemd-run` show up here even though no unit file exists (e.g. `openclaw-update2.service`). Also check `crontab -l` and `systemctl --user list-timers`.
5. Retry-loop evidence: numbered logs in /tmp (update.log, update2.log, update5.log...) reveal an updater that failed and re-fired; check timestamps.
6. Disk evidence: `du -sh` package stores (~/.local/share/pnpm/store, ~/.cache) — a big store predicts a multi-GB fresh install; recently modified package.json/lockfiles show when code was pulled.
7. Proxy note: if env has http_proxy/ALL_PROXY set (e.g. clash 7890/7891), ALL proxied traffic still counts on the physical link — the proxy is transparent for billing.

## Stopping / mitigation
- `systemctl --user stop <transient-service>` then kill leftover PIDs (pnpm install etc.).
- For auto-updaters that re-fire: find the check/update mechanism and disable or gate it (update only on demand / non-metered networks).

## Pitfalls
- `systemctl list-units` without `--user` misses user transient services — that's where the auto-update trigger hides.
- A "failed" update is not necessarily stopped: retry loops spawn numbered logs and new installs.
- Don't blame the obvious browser — check install/update processes first; node/pnpm installs of big monorepos are multi-GB.
- /proc/net/dev counters are cumulative since interface up — use them to size the damage, not as a live rate.

## Worked example: OpenClaw auto-update burned 4GB on a hotspot (2026-08-06)
- Symptom: 4GB gone right after switching to phone hotspot.
- Evidence chain: /proc/net/dev (wlp9s0 RX 3.8GB) → ps: `pnpm install` (cwd ~/projects/openclaw, 2.8GB RSS) + `openclaw-update` → /tmp/openclaw-update4.log + update5.log (retries!) → `systemctl --user list-units` showed transient `openclaw-update2.service` running `pnpm openclaw update --yes` → package.json/pnpm-lock.yaml mtime 00:18 = fresh git pull.
- Root cause: OpenClaw gateway auto-update mechanism — checks for new versions (update-check.json), then systemd-run's a transient service that stops the gateway, git-pulls, and `pnpm install`s ALL dependencies (multi-GB; pnpm store was already 21GB) through the clash proxy.
- Fix: stop the transient service + kill the install; for permanence disable the auto-update or only update on WiFi. Note: interrupting mid-install leaves node_modules half-built and the gateway stopped — a re-run of `pnpm openclaw update --yes` is needed to recover.
