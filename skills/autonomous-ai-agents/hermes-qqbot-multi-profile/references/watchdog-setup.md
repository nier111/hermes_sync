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
