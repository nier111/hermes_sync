# Diagnosing silently-lost QQ messages (bot "dead" while the process stays active)

Symptom: the user says the bot ignored them. From QQ, two very different causes look identical:

1. The message reached Hermes and the agent failed / never replied.
2. The message never reached Hermes at all (transport loss).

Never answer from the chat transcript alone — decide (1) vs (2) from evidence first.

## Step 1 — did the message actually arrive?

```bash
# main profile AND each per-profile gateway log
grep -n "<fragment of the user's message>" ~/.hermes/logs/gateway.log
grep -n "<fragment>" ~/.hermes/profiles/<name>/logs/gateway.log

# what the gateway actually received — last hops only
grep -E "inbound message:|response ready:|Sending response" ~/.hermes/logs/gateway.log | tail -30
```

Arrived ⇒ there is an `inbound message:` line with the same text.
No line ⇒ it never got in. Do not blame the model, the persona, or the agent loop.

Corroborate in SQLite (full layout in the `hermes-internals` skill):

```sql
-- default: ~/.hermes/state.db    per-bot: ~/.hermes/profiles/<name>/state.db
SELECT role, substr(content,1,60), datetime(timestamp,'unixepoch','localtime')
FROM messages WHERE content LIKE '%<fragment>%' ORDER BY timestamp DESC LIMIT 10;

-- what WAS delivered (outbound obligation queue)
SELECT state, datetime(created_at,'unixepoch','localtime'), substr(content,1,40)
FROM delivery_obligations ORDER BY created_at DESC LIMIT 10;

-- routing / liveness of the session row
SELECT entry_json FROM gateway_routing;
```

Absent from `messages` AND no `delivery_obligations` row ⇒ it was never processed.

## Step 2 — correlate with the network layer

Two bots going quiet in the same minute is a shared-network signature, not two model failures.

```bash
journalctl --since '<gap start>' --until '<gap end>' --no-pager \
  -u NetworkManager -u systemd-networkd -u wpa_supplicant
journalctl --user -u <proxy-unit> --since '<gap>' --until '<gap>' --no-pager
```

Look for `CTRL-EVENT-DISCONNECTED`, `link timed out`, `ssid-not-found`,
`dhcp4: state changed new lease`, `NetworkManager state is now CONNECTED_GLOBAL`,
and fresh TCP connects to `api.sgroup.qq.com:443`.

## Root cause confirmed 2026-09-18 (Aoi + Kubo both silent)

```
06:44:59  Kubo's last successful reply
06:45:31  Wi-Fi drops the phone hotspot (iQOO), reason=1
06:45:46  hotspot re-association fails (ssid-not-found), link timed out
06:45:49  NetworkManager auto-switches to campus i-NUIST
06:45:55  new DHCP lease 10.0.46.125
07:01:21  user manually restarts both gateways
07:01:23 / 07:01:25  Aoi / Kubo Ready — traffic resumes
```

The link/IP change leaves both QQ WebSockets **half-open**: the old TCP session is
gone on the wire while the local socket still reports open.

## Why the built-in reconnect loop never fires

In `~/.hermes/hermes-agent/gateway/platforms/qqbot/adapter.py`:

- `_heartbeat_loop()` sends `{"op": 1, "d": self._last_seq}`, but the `op 11`
  heartbeat-ACK branch is a bare `return` — no ACK timestamp, no missed-ACK count.
- A failed heartbeat send is only `logger.debug(...)`; it never closes the socket.
- `_read_events()` stays blocked on a socket that will never deliver data again.
- `_mark_transport_disconnected()` / `_reconnect()` therefore never run, and
  `systemctl is-active` keeps reporting `active` with `✓ qqbot connected` in the log.

`_listen_loop()`'s reconnect logic itself is fine — it is simply never triggered.

## Consequence: the lost messages are gone for good

`adapter.py` states it directly: *"QQBot has no server-side update queue."* QQ C2C does
not replay events sent while the Gateway session was dead, so unlike a mailbox there is
nothing to fetch after reconnect. A restart is the only recovery.

## Fix direction (proposed, not yet implemented)

Track the last heartbeat-ACK time; if two consecutive heartbeats get no `op 11`, close
the socket so `_listen_loop()`'s existing reconnect path takes over — self-heals within
~1–2 min instead of waiting for a manual restart.

## Pitfalls

- **`systemctl is-active` / `✓ qqbot connected` / `Ready, session_id=` are startup
  evidence, not liveness.** Judge liveness by recency of `inbound message:` lines.
- Don't "fix" this with a more aggressive restart watchdog — a half-open socket needs
  in-adapter detection, not a shorter timer.
- The reason the Wi-Fi link itself dropped (`reason=1` + `ssid-not-found`) usually is not
  recoverable from logs. Report the transport chain and say plainly which hop is unknowable.
