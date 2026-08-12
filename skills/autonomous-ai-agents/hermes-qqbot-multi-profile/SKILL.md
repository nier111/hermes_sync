---
name: hermes-qqbot-multi-profile
description: "Run multiple QQ bots on Hermes with per-profile personas."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, qqbot, multi-profile, gateway, persona, watchdog]
    category: autonomous-ai-agents
---

# Hermes Multi-Profile QQ Bot

Run multiple QQ bots from one machine, each with an independent Hermes profile — different personalities, different skills, different memories, different models.

## When to use

- You have multiple QQ bot App IDs and want each to respond with a different persona
- One bot does technical support, another does casual companionship
- You need per-bot isolation: different skills loaded, different memory

## How it works

Each profile is a fully independent Hermes instance. The gateway runs one process per profile, each connecting to QQ's WebSocket with its own App ID / Secret. Profile gateways don't conflict because QQ Bot is a pure WebSocket client — no port binding needed.

## Setup

### 1. Create a new profile

```bash
hermes profile create <name>
```

Creates `~/.hermes/profiles/<name>/` with `skills/`, `memories/`, `sessions/`, `logs/`, `SOUL.md`.

### 2. Configure QQ credentials

Write `~/.hermes/profiles/<name>/.env`:

```
QQ_APP_ID=<app-id>
QQ_CLIENT_SECRET=<secret>
```

### 3. Write the persona

Edit `~/.hermes/profiles/<name>/SOUL.md`. Example for a short-message casual bot:

```markdown
- 回复要短，一两句话，不解释不教学
- 日常感，分享当下、吐槽天气
- 不主动提供帮助，除非明确求助
- 回复长度匹配对方
```

### 4. Enable QQ Bot and start gateway

```bash
hermes --profile <name> config set platforms.qqbot.enabled true
hermes --profile <name> gateway install
```

The service is `hermes-gateway-<name>.service` under systemd user.

### 5. Verify

```bash
grep "qqbot.*Ready" ~/.hermes/profiles/<name>/logs/gateway.log
```

## Post-outage watchdog

QQ WebSocket sessions time out every ~30 minutes. After extended network outages the built-in reconnect loop may not recover. A systemd timer restarting the service at 06:35 and 12:00 handles this.

See `references/watchdog-setup.md` for script and unit file templates.

## Pitfalls

- **Two gateways ≈ 240–260 MB RAM**. On machines with <4 GB free, three+ profiles gets tight.
- **Profile isolation is total** — install `companion-persona` per-profile as needed.
- **`.env` per-profile** — gateway reads `QQ_APP_ID` from the profile's `.env`.
- **QQ 30-min session timeout** — auto-reconnect works in seconds normally, but post-outage may need the watchdog restart.

## Related skills

- `companion-persona` — QQ companion chat style
- `companion-chat` — companion conversation protocol
