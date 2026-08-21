# Android phone pairing via bluetoothctl — worked example (2026-08)

Host: Arch Linux, BlueZ 5.87 (bluetoothd). Phone: Android, name "ciallo", MAC 64:44:7B:7F:D5:F2.

## Failure mode observed
One-shot `bluetoothctl pair 64:44:7B:7F:D5:F2`:

```
Attempting to pair with 64:44:7B:7F:D5:F2
[CHG] Device 64:44:7B:7F:D5:F2 Connected: yes
Failed to pair: org.bluez.Error.AuthenticationFailed
EXIT=1
```

Phone side: "PIN or passkey incorrect" / Bluetooth manager stops responding.
Journal showed earlier failed attempts: `Hands-Free unit failed connect to ... Connection refused (111)`.

Root cause: no persistent agent. Each bluetoothctl invocation is a fresh process; the passkey
confirmation prompt dies unanswered, so pairing times out and the phone blames the code.

Extra observations:
- After `bluetoothctl remove <MAC>`, one-shot `pair` returns "Device not available" — the device
  must be re-discovered (`scan on`) before pairing again.
- One-shot `agent on` printed `No agent is registered` (agent did not persist across invocations).
- `bluetoothctl paired-devices` → "Invalid command in menu main" on bluetoothctl 5.87.

## Successful flow (persistent pty session)
terminal(background=true, pty=true) → `bluetoothctl`, then drive via process submit:

```
agent on          → Agent registered (auto at session start; then "Agent is already registered")
default-agent     → Default agent request successful
scan on           → Discovery started; [NEW] Device 64:44:7B:7F:D5:F2 ciallo
pair 64:44:7B:7F:D5:F2
                  → Attempting to pair ... Connected: yes
                  → Request confirmation
                  → [agent] Confirm passkey 900379 (yes/no):   ← answer YES here
yes               → Pairing successful, [CHG] ... Paired: yes
trust 64:44:7B:7F:D5:F2
connect 64:44:7B:7F:D5:F2
scan off
```

Note: right after pairing the phone dropped the connection
(`SIGNAL Disconnected ... Connection terminated by remote user`) — normal for Android.

Final `bluetoothctl info 64:44:7B:7F:D5:F2`:
```
Paired: yes   Bonded: yes   Trusted: yes   Connected: yes
```

Passkey codes are random per attempt (this session saw 620003 in a failed run, then 900379 in the
successful one) — always verify against the phone screen, never reuse an old code.
