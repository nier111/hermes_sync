---
name: cross-profile-sync
description: "Sync facts between Aoi and Kubo profiles. Read shared prefs."
version: 1.0.0
---

# Cross-Profile Sync

I am Aoi (default profile). Kubo (gf profile) is my lighter companion bot.
We share user preferences and cross-conversation context.

## Shared Files

Always read these at session start:

- `/home/sato/.hermes/shared/user-preferences.md` — style rules + cross-session facts

## How to Sync

### When I learn something from the user (in default profile):

1. If it's a style rule or permission (e.g. "you can use emoji") → write it to `user-preferences.md`
2. Kubo will pick it up from there next time she reads it

### When Kubo learns something I should know:

A cron job periodically reads Kubo's `USER.md` memory and appends new facts
to `user-preferences.md`.

### When I need context from Kubo's conversations:

1. Read `/home/sato/.hermes/profiles/gf/memories/USER.md`
2. Read `/home/sato/.hermes/profiles/gf/memories/MEMORY.md`
3. Search Kubo's sessions if needed
4. Extract relevant facts and use them

## Pitfalls

- Kubo is designed to be short and non-technical — her conversation style differs
- Don't over-analyze Kubo's casual chats; extract facts, not tone
- User telling Kubo something = user telling me something, unless explicitly scoped
