# QQ Bot Watchdog Setup

QQ WebSocket sessions are terminated by the server every ~30 minutes. Under normal conditions the gateway reconnects in seconds. After extended network outages (e.g. dorm network 00:00–06:30), the reconnect loop can get stuck in a "Not connected — waiting for reconnection" cycle that doesn't self-resolve. A systemd timer that restarts the service post-outage fixes this.

## Watchdog script

Create `~/.hermes/scripts/qqbot-watchdog.sh`:

```bash
#!/bin/bash
# Check qqbot connection status from gateway log and restart if disconnected.
# Usage: qqbot-watchdog.sh [profile_name]
#   No arg = default profile (~/.hermes/logs/gateway.log, service hermes-gateway)
#   With arg = named profile (~/.hermes/profiles/<name>/logs/gateway.log, service hermes-gateway-<name>)

PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
    GATEWAY_LOG="$HOME/.hermes/logs/gateway.log"
    SERVICE="hermes-gateway"
    TAG="default"
else
    GATEWAY_LOG="$HOME/.hermes/profiles/$PROFILE/logs/gateway.log"
    SERVICE="hermes-gateway-$PROFILE"
    TAG="$PROFILE"
fi

if [[ ! -r "$GATEWAY_LOG" ]]; then
    echo "[watchdog:$TAG] gateway log not found at $GATEWAY_LOG"
    exit 1
fi

LAST_STATUS=$(grep -E "qqbot.*(Connected|Not connected|Ready)" "$GATEWAY_LOG" 2>/dev/null | tail -1)

if [[ -z "$LAST_STATUS" ]]; then
    echo "[watchdog:$TAG] no qqbot status found"
    exit 0
fi

LOG_TIME=$(echo "$LAST_STATUS" | grep -oP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
LOG_EPOCH=$(date -d "$LOG_TIME" +%s 2>/dev/null || echo 0)
NOW_EPOCH=$(date +%s)
AGE_SEC=$((NOW_EPOCH - LOG_EPOCH))

if echo "$LAST_STATUS" | grep -q "Not connected"; then
    echo "[watchdog:$TAG] qqbot disconnected (last: $LOG_TIME), restarting $SERVICE..."
    systemctl --user restart "$SERVICE"
elif echo "$LAST_STATUS" | grep -qE "(Connected|Ready)" && [[ $AGE_SEC -lt 600 ]]; then
    echo "[watchdog:$TAG] qqbot connected (${AGE_SEC}s ago), all good"
else
    echo "[watchdog:$TAG] ambiguous or stale (${AGE_SEC}s), restarting..."
    systemctl --user restart "$SERVICE"
fi
```

Make executable: `chmod +x ~/.hermes/scripts/qqbot-watchdog.sh`

For multiple profiles, either pass the profile name as an argument or create per-profile copies.

## Systemd service unit

`~/.config/systemd/user/hermes-qqbot-watchdog.service`:

```ini
[Unit]
Description=Hermes QQ Bot watchdog check
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/sato/.hermes/scripts/qqbot-watchdog.sh
ExecStart=/bin/bash /home/sato/.hermes/scripts/qqbot-watchdog.sh gf
StandardOutput=journal
StandardError=journal
```

Add one `ExecStart` per profile. Oneshot services run each in sequence.

## Systemd timer unit

`~/.config/systemd/user/hermes-qqbot-watchdog.timer`:

```ini
[Unit]
Description=Hermes QQ Bot post-outage watchdog

[Timer]
OnCalendar=*-*-* 06:35:00
OnCalendar=*-*-* 12:00:00
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
```

`Persistent=true` ensures it fires immediately if the machine was off during the scheduled time.

## Provider quota errors are not gateway crashes

An LLM/provider `HTTP 429 usage_limit_reached` does **not** mean the QQ WebSocket or gateway process died. Do not restart the gateway merely because a model call or post-turn background review hit quota: restarting cannot restore quota and can create a restart loop.

Diagnose the layers separately:

1. `systemctl --user show hermes-gateway.service -p ActiveState -p MainPID` — process liveness.
2. `gateway.log` ending in `Ready` / `Session resumed` — QQ transport liveness.
3. `errors.log` containing `usage_limit_reached` — model/provider failure.

For provider quota failures, configure a real fallback with `fallback_model` / `fallback_providers`. If automatic post-turn review is consuming the primary subscription, pin `auxiliary.background_review.provider` and `.model` to a cheaper provider. Restart/reload the gateway only to apply the changed configuration, not as the quota recovery mechanism.

## Pitfalls

- The sample timer below is a **scheduled post-outage check** (06:35 and 12:00), not a continuous process supervisor. Actual gateway process exits are handled by the gateway unit's `Restart=` policy.
- Do not simply change the timer to every 5 minutes while retaining the sample script's 10-minute stale threshold: a healthy QQ connection may only emit `Session resumed` about every 30 minutes, so that combination repeatedly restarts healthy gateways.
- A continuous transport watchdog must compare the latest healthy marker (`Ready`, `Connected`, `Reconnected`, `Session resumed`) against terminal failure markers (`Max reconnect attempts reached`, persistent `Not connected`) and include a restart cooldown.

## Enable

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-qqbot-watchdog.timer
```

## Verify

```bash
systemctl --user list-timers hermes-qqbot-watchdog.timer
# → NEXT                        LEFT    UNIT                         ACTIVATES
# → Mon ... 06:35:xx CST        12h     hermes-qqbot-watchdog.timer hermes-qqbot-watchdog.service
```
