# Model-fallback forensics — did this turn actually switch providers?

Use when the user says any of: "why did your model change?", "you're on deepseek now?",
"I saw a fallback banner", "is the fallback working?", or when a bot's output style changes
and you suspect a silent provider swap. Do the evidence chain BEFORE writing a sentence of
explanation. Getting this backwards costs the user two turns of trust.

## The banner is real evidence — of *some* switch, not of *which* session

`🔄 Switched to fallback model: A via p1 → B via p2`

Emitted from exactly one place:

```text
~/.hermes/hermes-agent/agent/chat_completion_helpers.py  →  _try_activate_fallback()
    agent._pending_fallback_notice = (
        f"🔄 Switched to fallback model: {old_model} via {old_provider} "
        f"→ {fb_model} via {fb_provider}"
    )
```

(There is a sibling `↻ Switched to fallback: <model>` in `agent/conversation_loop.py` and a
startup-time `🔄 Fallback model: ...` in `agent/agent_init.py` — neither is the mid-turn
notice.) Verify the string still lives there before quoting source to the user:

```bash
grep -rn --exclude-dir=__pycache__ "Switched to fallback" ~/.hermes/hermes-agent/agent/
```

Consequence: a screenshot of that banner proves a switch occurred **in the fallback path of
some Hermes process** — it does NOT prove it was the session the user is staring at. On a box
with `hermes-gateway`, `hermes-gateway-gf` (other profiles) and OpenClaw all serving QQ,
attribute via timestamp, not via vibe.

## The evidence chain in logs/gateway.log

All of these land on the same provider path, per switch:

```bash
grep -n -E "Primary provider rate-limited|Fallback provider resolved|Runtime provider supplied explicit model override|Fallback activated|Fallback .*: reasoning_config" \
  ~/.hermes/logs/gateway.log | tail -30
```

Real sample:

```text
2026-09-19 11:18:19 WARNING gateway.run: Primary provider rate-limited (429): Codex provider quota exhausted (429); retry after 18888s. Credentials are still valid. — trying fallback
2026-09-19 11:18:19 INFO    gateway.run: Fallback provider resolved: minimax model=MiniMax-M3
2026-09-19 11:18:19 INFO    gateway.run: Runtime provider supplied explicit model override: gpt-5.6-sol -> MiniMax-M3
```

Then bracket the *turn in question*, not the clock:

```text
12:04:32,173  inbound message: platform=qqbot ... msg='...'
12:05:09,970  response ready: platform=qqbot chat=... time=37.8s api_calls=4 response=1391 chars
```

Decision table:

| Observation | Verdict |
|---|---|
| fallback trio appears between `inbound message` and `response ready` of that turn | real switch, that turn, on that session |
| fallback trio only on an *earlier* turn; current turn clean | no switch now — the session has been riding the fallback since then (the primary 429 is time-boxed, e.g. `retry after 18888s`) |
| banner in the user's screenshot, no trio anywhere near that turn | do NOT claim either way; ask which chat/timestamp the banner belongs to, and check the *other* gateways/profiles' logs |
| nothing anywhere, but the style looks like another model | style is not evidence. Say "style is not proof" and go get the trio |

## The wrong-window bug (this is the one that bit)

```bash
# WRONG — silently drops the fallback lines if they landed outside the window
awk '/^2026-09-19 12:0[0-5]:/' ~/.hermes/logs/gateway.log | grep -E "Fallback provider resolved"
```

Two ways this lies to you:

1. The switch can precede the message you're explaining by tens of minutes. Grep the whole
   file with `| tail -30`, *then* narrow to the turn.
2. `systemd` housekeeping SIGTERM-restarts the gateway (visible as `Received SIGTERM —
   initiating shutdown` → `Exiting with code 1 ... so systemd Restart=on-failure can revive
   the gateway` → `Starting Hermes Gateway...` two seconds later). A restart minutes before
   the turn splits the trace and makes a bounded window look empty.

## Two things that are NOT evidence

- `config.yaml` `model.default` / `fallback_providers` — says what a NEW turn *would* pick,
  not what answered. Users override per session; cron jobs pin their own model.
- The model's own answer to "what model are you?" — `rewrite_prompt_model_identity(agent,
  fb_model, fb_provider)` runs during the swap, so the self-identity follows the fallback. It
  is a mirror of the swap, never independent proof of it.

## Cross-check the per-model rollup

```sql
sqlite3 -header -column ~/.hermes/state.db \
  "SELECT datetime(last_seen,'unixepoch','localtime') t, model, billing_provider,
          api_call_count, input_tokens, output_tokens
   FROM session_model_usage ORDER BY last_seen DESC LIMIT 10;"
```

If the turn really ran on the fallback, that model gains an `api_call_count` row at the same
timestamp. Per-profile bots: `~/.hermes/profiles/<name>/state.db` (separate DB).

## Reporting rules for this class of question

1. State the log window you actually searched, and the exact grep you ran.
2. Separate "what the log says" from "what would explain it". If the two don't converge, say
   so — an honest "the banner and the log disagree, here's how we tell them apart" beats a
   confident wrong attribution.
3. If you already asserted the opposite in an earlier turn, correct it explicitly and list
   which earlier statements are now void. The user tracks logical chains and will replay them.
