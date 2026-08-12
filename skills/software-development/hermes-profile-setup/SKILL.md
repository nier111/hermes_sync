---
name: hermes-profile-setup
description: "Use when creating Hermes profiles. LLM before platform."
version: 1.0.0
author: Hermes Agent
license: MIT
---

# Hermes Profile Setup Checklist

When creating a new Hermes profile, follow this order. LLM config is the #1 thing people forget.

## Setup Order

1. **Create profile**
   ```bash
   hermes profile create <name>
   ```

2. **LLM config (DO THIS FIRST — profile does NOT inherit default credentials)**
   ```bash
   hermes --profile <name> config set model.provider <provider>
   hermes --profile <name> config set model.default <model>
   ```
   Then copy the API key to `~/.hermes/profiles/<name>/.env`:
   ```bash
   grep "^<PROVIDER>_API_KEY=" ~/.hermes/.env >> ~/.hermes/profiles/<name>/.env
   ```

3. **Platform credentials** (QQ Bot example)
   ```bash
   # Write to ~/.hermes/profiles/<name>/.env:
   QQ_APP_ID=<id>
   QQ_CLIENT_SECRET=<secret>
   ```

4. **Access control** (for personal bots)
   ```bash
   hermes --profile <name> config set platforms.qqbot.extra.dm_policy open
   echo "QQ_ALLOW_ALL_USERS=true" >> ~/.hermes/profiles/<name>/.env
   echo "QQBOT_HOME_CHANNEL=<user_openid>" >> ~/.hermes/profiles/<name>/.env
   ```

5. **Personality** — write `SOUL.md`

6. **Install + start gateway**
   ```bash
   hermes --profile <name> gateway install
   ```

7. **Watchdog** — add to `~/.config/systemd/user/hermes-qqbot-watchdog.service`

## Pitfalls

- **Profile does NOT inherit default credentials** — no API key, no provider, nothing. Always copy keys explicitly.
- **`dm_policy: open` alone fails** — gateway refuses to start without `QQ_ALLOW_ALL_USERS=true`.
- **Missing `QQBOT_HOME_CHANNEL`** — QQ shows "no home channel" and bot can't reply.
- **Forget to add watchdog** — new profile's gateway won't auto-recover after dorm network outage.
