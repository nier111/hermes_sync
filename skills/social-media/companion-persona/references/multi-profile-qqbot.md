# Multi-Profile QQ Bot Setup

Run multiple QQ bots from one machine, each with independent persona, memory, and skills.

## Why profiles

Hermes profiles isolate config, sessions, skills, memory, and .env per instance. Two QQ bots with different personalities need separate profiles so they don't share conversation history or persona rules.

## Step-by-step

### 1. Create the profile

```bash
hermes profile create <name>   # e.g., "gf"
```

This creates `~/.hermes/profiles/<name>/` with its own skills, memory, sessions, .env, config.yaml, SOUL.md.

A wrapper script is created at `~/.local/bin/<name>` for convenience.

### 2. Write the persona

Edit `~/.hermes/profiles/<name>/SOUL.md` with the bot's chat style rules. Keep it focused:

- Response length rules (short/long)
- Tone and personality
- What NOT to do (no tech advice, no bullet points, no "how can I help")
- Example replies

### 3. Configure .env

```bash
QQ_APP_ID=<app_id>
QQ_CLIENT_SECRET=<secret>
QQ_ALLOW_ALL_USERS=true
QQBOT_HOME_CHANNEL=<user_openid>
```

All four are REQUIRED. Without `QQBOT_HOME_CHANNEL`, the bot can receive but cannot reply (shows "no home channel").

### 4. Set DM policy to open

```bash
hermes --profile <name> config set platforms.qqbot.extra.dm_policy open
```

Default policy is `pairing` which requires a pairing code. For personal bots, `open` is simpler.

**GOTCHA**: Setting `dm_policy: open` without `QQ_ALLOW_ALL_USERS=true` in .env causes the gateway to **refuse to start** with:
```
Refusing to start: qqbot has dm_policy set to 'open' but QQ_ALLOW_ALL_USERS is not enabled
```

### 5. Install and start the gateway

```bash
hermes --profile <name> gateway install   # installs + enables + starts systemd service
```

The service is named `hermes-gateway-<name>.service`. Verify with:
```bash
hermes --profile <name> gateway status
grep "qqbot.*Ready" ~/.hermes/profiles/<name>/logs/gateway.log
```

### 6. Find the user's OpenID

If already chatting with the bot, the OpenID appears in gateway logs:
```
Unauthorized user: DABAA3BB1A28E03BA82F4AB94AC64BE7 (None) on qqbot
```

Set it as `QQBOT_HOME_CHANNEL` and the bot will be able to reply.

### 7. Add watchdog for post-outage recovery

Each profile needs its own watchdog. After dorm network outage (00:00-6:30), the QQ WebSocket session times out and may not auto-recover.

Watchdog script pattern (save as `~/.hermes/scripts/qqbot-watchdog-<name>.sh`):
```bash
#!/bin/bash
GATEWAY_LOG="$HOME/.hermes/profiles/<name>/logs/gateway.log"
SERVICE="hermes-gateway-<name>"
# Check last qqbot status line, restart if "Not connected"
```

Add to the watchdog timer service with an extra `ExecStart=` line.

## Pitfalls

- **Wrong profile**: Running `hermes gateway restart` restarts the DEFAULT profile. Use `hermes --profile <name> gateway restart` for others.
- **Memory pressure**: Each gateway instance uses ~110-130 MB. With 7.4 GB RAM and three services already running (~2 GB available), 2-3 QQ bot instances is the practical limit.
- **Dorm network outage**: QQ WebSocket sessions time out during the 00:00-6:30 blackout. The 6:35 AM watchdog trigger handles recovery — but only if the watchdog is set up for that profile.
- **Session timeout cycle**: QQ server kicks WebSocket every ~30 minutes (`Session timed out`). Normally auto-reconnects in seconds, but after prolonged disconnection it may fail permanently — watchdog catches this.
