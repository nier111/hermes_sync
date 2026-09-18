# Restarting a Hermes gateway for real (and proving it reconnected)

Applies to `hermes-gateway.service`, `hermes-gateway-<profile>.service`, and every other gateway unit.

## A restart is required more often than it looks

A code change (adapter patch, credential change, Wi-Fi/reconnect fix, config edit on a key the process reads at boot) takes effect **only after a real process restart**. None of these are restarts:

- `systemctl enable --now <unit>` on an already-running unit
- editing `.env` / `config.yaml` / adapter source
- `ActiveState=active`, a green systemd state, or a PID that "looks fine"

The running process keeps executing the old code until it is replaced.

## Self-restart guard — and the way around it

When the shell issuing the command is **itself a child of the gateway** (a gateway-hosted agent turn, a cron run, a review turn), all of these are refused with "cannot restart or stop the gateway from inside the gateway process":

```bash
systemctl --user restart hermes-gateway.service      # refused
hermes gateway restart                               # refused
systemd-run --user --unit=... --on-active=2s systemctl --user restart ...   # refused too
```

The reason: SIGTERM to the gateway propagates to its children, so the restart command would be killed halfway through. The refusal is a **deliberate guard, not a systemd or Hermes bug** — do not try to disable it.

Let systemd's *user manager* issue the restart instead, so the request does not originate inside the dying process tree:

```bash
busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager RestartUnit ss hermes-gateway.service replace

# second bot / profile (example unit name)
busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager RestartUnit ss hermes-gateway-gf.service replace
```

Each call returns an object path such as `o "/org/freedesktop/systemd1/job/22109"`. That path means **"job accepted"**, not "restart completed" — you must still verify.

From a plain terminal that is not gateway-hosted, `hermes gateway restart` and `systemctl --user restart` work normally. Use them there.

## Verify: PID change + handshake line in the LOG FILE

```bash
# snapshot before, then wait for the PID to actually change
systemctl --user show hermes-gateway.service -p MainPID --value
```

After the restart, confirm the QQ handshake in the **file** log:

```
Connecting to qqbot...
[QQBot:<app-id>] Access token refreshed, expires in Ns
[QQBot:<app-id>] Gateway URL: wss://api.sgroup.qq.com/websocket
[QQBot:<app-id>] WebSocket connected to wss://api.sgroup.qq.com/websocket
[QQBot:<app-id>] Connected
✓ qqbot connected
[QQBot:<app-id>] Ready, session_id=<uuid>
```

Which file:

| scope | log path |
|---|---|
| primary profile | `~/.hermes/logs/gateway.log` |
| named profile bot | `~/.hermes/profiles/<name>/logs/gateway.log` |

A **new `session_id=`** is the proof of a fresh QQ session. The previous session is dead; QQ does not replay C2C events that arrived during the gap, so a message sent while the socket was stale is simply lost.

### journalctl will mislead you

`journalctl --user -u hermes-gateway.service` carries only systemd's own lines (`Started ...`, `Failed with result 'exit-code'`, unit consumption) plus the agent's API-retry noise. It does **not** contain the adapter's INFO handshake lines, so a completely successful restart can look like "nothing happened / it failed". Grep the log FILE instead — e.g. `search_files` for a `YYYY-MM-DD HH:MM:` prefixed pattern such as `2026-09-19 04:53:.*(Access token|WebSocket connected|Ready)`.

Also check the log file's **mtime** (`stat -c '%y' <log>`). If it predates the restart, the new process has not reached the adapter yet — keep waiting instead of declaring success.

## "No response" triage order

Before touching anything, separate the three layers — a silent bot is usually one of:

1. **Dead socket, live process.** systemd says `active` / adapter once said `Connected`, but no `inbound message:` lines. See the Wi-Fi switching pitfall in SKILL.md (half-open WebSocket after network change); heartbeat-ACK tracking must close the stale socket. Fix = real restart (above), not `systemctl start`.
2. **Slow model generation.** Grep the log for `response ready: ... time=NNNs`. A 100 s+ generation is indistinguishable from a hang from inside QQ, but the transport is fine — do not restart for this. Report the real latency number.
3. **Provider unreachable.** `APIConnectionError` / `usage_limit_reached` retry storms in the log are an LLM problem, not a transport problem; restarting cannot fix quota (see the quota section in `watchdog-setup.md`).

Only layer 1 is fixed by a restart. Say which layer you found rather than restarting reflexively.
