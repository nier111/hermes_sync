---
name: arch-linux-maintenance
description: "Use when maintaining Arch Linux (updates, cleanup, dkms)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [arch, pacman, dkms, cleanup, disk, sudo, nvm, pnpm]
---

# Arch Linux Maintenance

Recurring maintenance workflows for the user's Arch boxes (laptop + future ITX). Covers update hygiene, disk cleanup, kernel/driver rebuilds, and the Hermes-terminal sudo quirks that bite every privileged operation.

## Update hygiene & news

- Official news RSS: `curl -s https://archlinux.org/feeds/news/` — parse `<item>` titles; watch for "requires manual intervention", kernel/NVIDIA/systemd/security items before big updates. reddit r/archlinux JSON is usually blocked by anti-scraping; don't depend on it.
- A daily watch job exists as Hermes cron "arch-每日更新简报" (14:00, delivers to QQ) — point the user there instead of hand-checking each session.
- NVIDIA driver news matters here: MX450 (Turing) is fine on current drivers, but major driver releases (e.g. the Open Kernel Modules switch) change what the dkms module must be built against.

## pacman cleanup (typical haul: 2-7 GB)

- `sudo pacman -Sc --noconfirm` — drop old package cache versions, keep installed ones (`-Scc` nukes everything, more aggressive).
- **Stale lock**: after an interrupted/killed pacman, `/var/lib/pacman/db.lck` lingers → "failed to init transaction (unable to lock database)". Confirm no pacman process (`ps aux | grep pacman`), then `sudo rm /var/lib/pacman/db.lck`.
- Journal: `sudo journalctl --vacuum-time=7d`.

## Disk cleanup checklist (2026-08-06, ~14 GB reclaimed on this box)

| Target | Command / action | Notes |
|---|---|---|
| pnpm store (largest, 22G→14G) | `pnpm store prune` | safe: removes unreferenced packages only |
| ~/.cache/yay | `rm -rf ~/.cache/yay` | AUR build cache, rebuildable |
| ~/.cache/drkonqi | `rm -rf ~/.cache/drkonqi` | KDE crash reports |
| uv cache | `uv cache clean` | |
| ~/.cache/pnpm | `rm -rf ~/.cache/pnpm` | download cache |
| mozilla cache | `rm -rf ~/.cache/mozilla` | only when firefox not running |
| chromium cache | skip while chromium running (check `ps aux | grep chromium`) | ~1.5G when idle; browser-tool orphans killable — see openclaw-interop skill |
| nvm old node | `nvm use <new> && nvm uninstall <old>` | nvm refuses to uninstall the "currently-active" version |
| journal | `sudo journalctl --vacuum-time=7d` | |

Never touch: `~/.minecraft`, `~/.espressif` (ESP-IDF toolchain), `~/projects`, package-manager state outside caches.

## dkms drivers (lts kernel + NVIDIA)

- Symptom: `nvidia-smi` fails but `dkms status` shows the module built only for a DIFFERENT kernel (compare against `uname -r`).
- Fix: install matching headers (`sudo pacman -S linux-lts-headers`), then `dkms autoinstall`. The pacman hook runs the build — it takes 5-15 min and is memory-hungry (~3.7GB peak for nvidia-open-dkms). Do NOT interrupt; poll instead:
  ```bash
  for i in $(seq 1 38); do dkms status | grep -q "$(uname -r).*installed" && break; pgrep -f "dkms install" >/dev/null || break; sleep 15; done
  ```
- A hung foreground `pacman -S` that times out under the Hermes terminal can leave the dkms hook still compiling — the fix is to wait for the hook, not to kill it.

## node/pnpm toolchain

- Full recipe for engines-gated pnpm projects (OpenClaw) lives in the `openclaw-interop` skill — summary: `nvm install 22.22.3 && nvm alias default 22.22.3`, `corepack enable` (shim lands in the CURRENT nvm bin dir), never the pacman `/usr/bin/pnpm`.
- **Hermes terminal env is a per-command snapshot**: `nvm use` / `export` inside one command does NOT persist to the next. Prefix every dependent command with `export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"`.

## sudo under the Hermes terminal (verified 2026-08-06)

- **Just write `sudo <cmd>` directly** — the Hermes terminal auto-wraps sudo and injects credentials (approval prompt says "combined-flag privilege escalation"). No password plumbing needed.
- **Do NOT use `sudo -A ...`**: it collides with the auto-wrapper and dies with `sudo: the -A and -S options may not be used together` (or a usage dump). This was the documented workaround in older sessions; the direct `sudo` path supersedes it.
- If an askpass script is involved (legacy flows), it must be executable: `chmod +x ~/.hermes/askpass.sh`, and it reads `SUDO_PASSWORD` from `~/.hermes/.env` — never echo passwords into command lines.

## Misc pitfalls

- Long sessions can span days (this one ran 03:00 → 17:00): confirm the real time with `date` before making temporal claims; tool output timestamps (dist mtime, process start times) are reliable clues.
- `web_search` backend (ddgs) can fail with `InvalidURL: Invalid port: '127.0.0.1:7891'` when the socks port leaks into its proxy handling — fall back to `curl -x http://127.0.0.1:7890 <url>` for the same lookups.
