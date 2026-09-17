# Bot ownership & usage attribution

Use when the user asks "how much has <person>'s bot used?" or "which bot is that?".

## On this machine

| profile | owner | QQ app id |
|---|---|---|
| (main / default) | 用户本人 + Aoi | DM `83ECED7607DD4DC378B441144891D01D` |
| `gf` | **用户本人** (Kubo / 久保渚咲) | 1905411221 |
| `friend` | **朋友** | 1905582666 |

Do **not** assume the newest or best-known profile belongs to the person being asked
about. In 2026-09 a usage question about the friend's bot was first answered from
`profiles/gf/state.db` (the user's own bot) and reported 356 DeepSeek + 55 GPT calls
that had nothing to do with the friend — the user corrected it.

Evidence for the mapping: `[QQBot:<app_id>]` log prefixes plus `user=<user_id>` on
`inbound message:` lines in that profile's `logs/gateway.log`.

## Checklist

1. Enumerate every profile DB (`Path.home().joinpath('.hermes').glob('**/state.db')`).
2. Confirm which profile the *person* in the question actually uses.
3. Query that profile's `state.db`, grouping `session_model_usage` by the joined
   `sessions.user_id` so `user_id=''` setup/test traffic is excluded.
4. If `session_model_usage` is empty or the token/`api_call_count` columns are `0`,
   count real calls from the logs instead — `response ready: ... api_calls=N`,
   `Turn ended: ... api_calls=N/500`, `API call failed (attempt n/3)`.
5. Count real `inbound message:` lines before calling a session "N rounds" — gateway
   sessions accumulate `session_meta` rows, restart notices, attachment echoes, and
   the user's own configuration test sends.
6. Report the profile path, the owning human, the real traffic, and a plain
   negligible-or-not conclusion. If an earlier answer used the wrong profile, say so
   and re-derive rather than quietly restating numbers.

Full SQL, the log-signal table, and the worked friend-bot example:
`hermes-internals` → `references/per-profile-usage-attribution.md`.
