---
name: linux-bluetooth
description: Use when pairing/connecting Bluetooth devices on Linux.
---

# Linux Bluetooth (BlueZ/bluetoothctl) pairing & troubleshooting

Use when a Bluetooth device (phone, earbuds, keyboard...) won't pair or connect on Arch/Linux, or when pairing a new device from the terminal.

## 1. Read the current state first
- Service: `systemctl status bluetooth --no-pager | head -20` (must be active/running)
- Adapter: `bluetoothctl list`, then `bluetoothctl show | head -25` — check `Powered: yes`
- Discovered: `bluetoothctl devices`; device detail: `bluetoothctl info <MAC>` — check `Paired: / Bonded: / Trusted: / Connected:`
- Errors: `journalctl -u bluetooth --no-pager -n 30`

If the target shows `Paired: no`, the problem is PAIRING, not connecting — fix pairing first.

## 2. Pairing workflow that actually works

CRITICAL PITFALL: `bluetoothctl` one-shot commands run in a FRESH PROCESS each time. An agent registered via `agent on` dies when that process exits, so the passkey prompt (`[agent] Confirm passkey NNNNNN (yes/no):`) has nobody answering → pairing hangs, then fails with `org.bluez.Error.AuthenticationFailed`, and the PHONE side reports "PIN/配对码不正确" or "Bluetooth manager not responding". It looks like the phone rejected the code — it didn't.

Fix: run a PERSISTENT interactive bluetoothctl session (terminal background=true + pty=true), drive it with process submit, and answer `yes` when the passkey prompt appears:

1. Start: terminal(background=true, pty=true) → `bluetoothctl`
2. submit `agent on`, then `default-agent` (agent survives inside this session)
3. submit `scan on`; wait ~5-6s for the device to reappear
4. submit `pair <MAC>`
5. poll until `[agent] Confirm passkey NNNNNN (yes/no):` appears
6. Tell the user to check the phone for the SAME 6-digit code and tap Pair/Allow — both ends must show the same number
7. submit `yes` → expect `Pairing successful` / `Paired: yes`
8. Phone may drop the connection right after pairing — that is normal, `connect` again
9. submit `trust <MAC>`, then `connect <MAC>`
10. submit `scan off` to stop discovery
11. Verify: fresh `bluetoothctl info <MAC>` — Paired/Bonded/Trusted/Connected all `yes`

## Pitfalls
- Stale cache: after repeated pairing failures, `bluetoothctl remove <MAC>` first (and delete the PC entry in the phone's BT settings if present), re-scan, then pair. After remove, one-shot `pair` returns "Device not available" until re-discovered.
- One-shot `agent on` may print `No agent is registered` and do nothing — the fresh-process trap; only a persistent session keeps the agent.
- `bluetoothctl paired-devices` is NOT valid in newer bluetoothctl (5.87); use `bluetoothctl devices` / `info`.
- Passkey codes are random per attempt (620003 → 900379 → ...). Never reuse an old code; a failed code does not mean the phone is broken.
- Keep the phone's Bluetooth settings screen open during pairing so its confirmation dialog actually appears.

## References
- references/android-phone-pairing.md — full worked example: real failure output + successful passkey flow (phone 64:44:7B:7F:D5:F2 "ciallo", BlueZ 5.87).
