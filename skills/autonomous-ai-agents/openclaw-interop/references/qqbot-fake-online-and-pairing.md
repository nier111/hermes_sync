# OpenClaw QQ bot: "假在线" (fake-online) and post-restart pairing

Verified 2026-09-19 on this box. Companion to the "QQ Bot health check" section of SKILL.md —
read this whenever a QQ bot is reported as not answering.

## Symptom

- `systemctl --user is-active openclaw-gateway.service` → `active`, MainPID alive for **days**, `NRestarts=0`.
- `openclaw status` → `QQ Bot: ON / OK`.
- User messages the QQ bot → nothing. No inbound event appears in the gateway log at all.
- The classic trigger is a **network switch** (phone hotspot → campus Wi-Fi, or vice versa). Switching
  networks silently kills the QQ WebSocket; the old process never fully reconnects and keeps only its
  own localhost loopback socket, so every liveness signal derived from the process looks fine.

Do NOT close such a report as "normal 4009 reconnect, it recovers". Verify with sockets.

## Authoritative check: sockets, not status text

```bash
systemctl --user show openclaw-gateway.service -p MainPID   # -> MainPID=2883426
ss -tnp | grep "pid=2883426"
```

Healthy output contains a real outbound to Tencent, e.g.:

```
ESTAB  0 0  10.234.151.74:53044  112.65.194.180:443  users:(("node",pid=2883426,fd=43))
```

Fake-online output contains ONLY loopback pairs (the CLI / control UI talking to the gateway):

```
ESTAB  0 0  127.0.0.1:44384   127.0.0.1:18789  users:(("node",pid=...,fd=44))
ESTAB  0 0  127.0.0.1:18789   127.0.0.1:44384  users:(("node",pid=...,fd=45))
```

## Log signature of the dead channel

`/tmp/openclaw/openclaw-<YYYY-MM-DD>.log` fills with a repeating triple, roughly every 15s:

```
[qqbot:token:1903729635] Network error: This operation was aborted
[qqbot:token:1903729635] Background refresh failed: Network error getting access_token: *** operation was aborted
... EAI_AGAIN bots.qq.com ...
```

Hundreds of consecutive lines of this = the channel never recovered. `[gateway] ready` at startup
does NOT imply the QQ channel is up — the channel connects a second or two later.

## Fix and verification

```bash
systemctl --user restart openclaw-gateway.service
```

Then verify all three:
1. socket: `ss -tnp | grep "pid=<new_pid>"` shows `-> 112.65.194.180:443`.
2. `journalctl --user -u openclaw-gateway.service --since '-3 min'` shows:
   ```
   [qqbot] [default] [default] ✅ Access token obtained
   [qqbot] [default] [default] Connecting to wss://api.sgroup.qq.com/websocket
   [qqbot] [default] [default] WebSocket connected
   [qqbot] [default] [qqbot] gateway READY
   [qqbot] [default] Gateway ready
   ```
3. content-free smoke test: ask the user to send one message and confirm it arrives.

## Second trap: `pairing required` after restart

Newer OpenClaw locks inbound DMs by default (`dmPolicy=pairing`). The first DM after a restart can land as:

```
[qqbot] [default] [access] pairing required for 5D2C9FF277D7F2D7709F1F6C18620AA7
```

Reading: the message DID reach the bot; the QQ user simply has no grant yet. The user experiences it as
"restart did nothing, it still ignores me". Also note the `[access]` line does NOT appear in
`openclaw status` output, so status-based triage misses it.

**Confirm with the user that the request is theirs before approving.** Two unrelated events in a row
(restart, then a first DM) are not proof that a pending pairing request is legitimate — asking is cheap,
auto-granting DM access to a stranger is not.

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"
openclaw pairing list qqbot
#   Code      userId                            Meta                    Requested
#   CPMT9KA7  5D2C9FF277D7F2D7709F1F6C18620AA7  {"accountId":"default"}  2026-09-18T21:14:35Z
openclaw pairing approve qqbot CPMT9KA7
openclaw pairing list qqbot          # -> "No pending qqbot pairing requests."
```

Approval output also reports a side effect worth knowing:

```
Approved qqbot sender 5D2C9FF277D7F2D7709F1F6C18620AA7.
Command owner configured qqbot:5D2C9FF277D7F2D7709F1F6C18620AA7 (commands.ownerAllowFrom was empty).
```

The message that triggered pairing is **not** replayed after approval — the user must send a new one.

`openclaw pairing [list|approve]` with the channel omitted defaults to the sole available pairing
channel, and it also accepts a positional provider (`pairing approve <provider> <code>`).

## Pitfall: use the installed CLI for state-DB commands

Running the CLI out of the repo checkout can abort before printing anything:

```bash
cd ~/projects/openclaw && pnpm openclaw status
# Error [SqliteSchemaVersionError]: OpenClaw agent database
# /home/sato/.openclaw/agents/main/agent/openclaw-agent.sqlite uses newer schema version 19;
# this build supports 16. Refused by OpenClaw 2026.7.2 (36dbbd7) installed at /home/sato/projects/openclaw
```

The checkout's linked build (2026.7.2) is older than the state dir's schema. The npm-installed global
CLI (2026.8.1 at the time of writing) reads it fine, so for `status`, `pairing`, and anything else that
opens the state DB:

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"
openclaw --version      # e.g. OpenClaw 2026.8.1 (ea80657)
openclaw status
```

`pnpm openclaw agent --agent main -m "..."` (agent calls) remains valid from the repo dir.

Related pitfall: `openclaw` and `pnpm openclaw` resolve to DIFFERENT builds on this machine, so a
version string from one is not evidence about the other. Check which binary answered before trusting
a version or a schema-support claim.

## Real timeline (2026-09-19, 凌晨)

```
06:45  Wi-Fi switches hotspot -> campus net; QQ WebSocket goes silent for BOTH Hermes gateways
       and OpenClaw. Processes stay active; watchdogs do not fire (nothing looks down).
05:11  Desktop session restarts the Kubo Hermes gateway (pid 2461728 -> 2857928) to load new
       memory limits, then inspects OpenClaw.
       Old OpenClaw pid 1192: active, status shows QQ OK, but ss shows loopback only -> fake-online.
05:12:48  systemctl --user restart openclaw-gateway.service (pid 1192 -> 2883426)
05:12:55  WebSocket connected / gateway READY; new ESTAB 10.234.151.74:53044 -> 112.65.194.180:443
05:14:35  [access] pairing required for 5D2C9FF277D7F2D7709F1F6C18620AA7   <- user's own test DM
          openclaw pairing list qqbot -> CPMT9KA7 -> approve qqbot CPMT9KA7 -> no pending requests
```

Lesson from the whole round: a QQ bot has **three** independent liveness layers — process/service,
socket/WebSocket, and per-user access grant. Checking only the first reports "all good" while the user
sees silence. Check all three in that order.
