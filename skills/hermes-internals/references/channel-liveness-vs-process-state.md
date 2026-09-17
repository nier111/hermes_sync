# Channel liveness ≠ process state (read this before trusting step 2/3 of "Proving a channel is ACTUALLY connected")

The SKILL.md checklist (`channel_directory.json` entry → `Connecting to …` → `✓ <platform> connected`
→ `Ready, session_id=…`) is **startup/handshake evidence only**. It answers "did the gateway ever
connect?", not "is it receiving right now?"

A gateway can simultaneously be:

- `systemctl --user is-active hermes-gateway` → `active`
- logging `✓ qqbot connected` and `Ready, session_id=…`
- and be a **half-open WebSocket** that will never deliver another event.

## What causes a half-open channel

Any link/identity change under a live socket: Wi-Fi band or SSID switch (hotspot ↔ campus
network), DHCP renewal, NAT/route reset, proxy restart, VPN toggle. The local socket still
reports open; the far end's TCP session is already gone. Heartbeats get buffered or dropped
without the client noticing.

## The correct liveness check

```bash
# recency of real traffic is the proof — not the presence of a "connected" line
grep -E "inbound message:|response ready:" ~/.hermes/logs/gateway.log | tail -20
```

Per-profile bots: `~/.hermes/profiles/<name>/logs/gateway.log`.

If the last `inbound message:` is old while the user insists they have been messaging, suspect a
half-open socket, not a model problem.

## Decision rule for "the bot didn't reply"

Establish arrival before diagnosing the agent:

| Evidence | Conclusion |
|---|---|
| `inbound message:` line with the user's text | Reached Hermes — now look at the agent/turn |
| Line absent, text also absent from `messages` and no `delivery_obligations` row | Never arrived — transport loss, model is not at fault |
| `delivery_obligations` row with `state='delivered'` | Hermes produced and sent a reply; if the user saw nothing, the loss is downstream |

## Recovery and durability

- Restarting the gateway is the only recovery for a half-open socket; QQ C2C has no server-side
  update queue, so messages sent during the dead window are **not** replayed.
- Restart alone does not prevent recurrence. In-adapter heartbeat-ACK timeout detection does
  (details and the confirmed 2026-09-18 incident: `hermes-qqbot-multi-profile` →
  `references/silent-message-loss-diagnosis.md`).

## Pitfall

Do not "fix" silence by shortening watchdog intervals. A timer can only restart a channel that has
already been *detected* as broken; detection is the missing piece here.
