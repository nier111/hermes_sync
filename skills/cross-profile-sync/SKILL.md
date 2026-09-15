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
to `user-preferences.md`. Do **not** stop at the two memory files — they go
stale (Kubo doesn't always compact them). Cheap 3-step sweep, in order:

1. **mtimes first**: `stat -c '%y %n'` on `gf/memories/USER.md`,
   `gf/memories/MEMORY.md`, `shared/user-preferences.md`. If the shared file is
   newer than both memory files, those files hold nothing new — but still do 2 and 3.
2. **Kubo's session DB** (`gf/state.db`, tables `sessions`/`messages`, times are
   unix epochs → `datetime(timestamp,'unixepoch','localtime')`): find the newest
   message. Anything newer than the shared file's mtime is a candidate fact.
3. **Kubo's gateway log** (`gf/logs/gateway.log`) — messages that never reached
   the DB live only here. Diff log against DB:

   ```bash
   cd /home/sato/.hermes/profiles/gf && python3 - << 'EOF'
   import re, sqlite3
   msgs=[(l[:19], m.group(1)) for l in open('logs/gateway.log',errors='replace')
         for m in [re.search(r"inbound message: platform=qqbot user=\S+ chat=\S+ msg='(.*?)' reply_to", l)] if m]
   stored=[r[0] or '' for r in sqlite3.connect('state.db').execute(
           "select content from messages where role='user'")]
   for ts,c in msgs:
       if not any(c[:30] in s for s in stored): print('LOST', ts, c[:120])
   EOF
   ```

   `LOST` lines are real user facts captured nowhere else. Note the log truncates
   each message to ~78 chars, so quote only what you can actually read.

### When I need context from Kubo's conversations:

1. Read `/home/sato/.hermes/profiles/gf/memories/USER.md`
2. Read `/home/sato/.hermes/profiles/gf/memories/MEMORY.md`
3. Search Kubo's sessions if needed
4. Extract relevant facts and use them

## Pitfalls

- Kubo is designed to be short and non-technical — her conversation style differs
- Don't over-analyze Kubo's casual chats; extract facts, not tone
- User telling Kubo something = user telling me something, unless explicitly scoped
- **Silent message loss**: when Kubo's primary provider auth fails
  (`Primary provider auth failed: No Codex credentials stored` →
  `trying fallback`, `api_calls=0`), the inbound user message is never persisted.
  Seen 2026-09-14 05:51/05:53. Only the gateway log has it.
- **`state.db` mtime lies**: it can be *older* than the newest message
  (WAL/checkpoint). Trust `max(timestamp)` from `messages`, not file mtime.
- Cron jobs on the `gf` side keep the profile directory "active" (heartbeats,
  `ticker_*`, `channel_directory.json`) — a fresh mtime there is not user activity.
- Only *read* from `gf/` in a scheduled run; writing Kubo's memories is a
  cross-profile edit and needs the user's explicit OK.
- Report found nothing as "无新增事实" **plus the evidence checked** (paths +
  mtimes + max message timestamp). Silent `[SILENT]` alone has been less useful
  for this job.
