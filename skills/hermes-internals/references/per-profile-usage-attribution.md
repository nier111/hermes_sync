# Per-profile usage attribution — queries, log fallbacks, worked example

Answers "how much has <person>'s bot used?" on a multi-profile Hermes box without
mis-billing one profile's traffic to another person.

## 1. Enumerate every DB first (do not assume one profile)

```python
from pathlib import Path
for p in Path('/home/sato/.hermes').glob('**/state.db'):
    print(p)
```

Returns, on this machine:

```text
/home/sato/.hermes/state.db                                  # main profile
/home/sato/.hermes/state-snapshots/20260817-021737-pre-update/state.db
/home/sato/.hermes/profiles/gf/state.db                      # user's own bot (Kubo)
/home/sato/.hermes/profiles/friend/state.db                  # the bot handed to a friend
```

`search_files(target='files', pattern='state.db')` returned only the top-level one —
the glob above is the reliable enumeration.

## 2. Human ↔ profile mapping (ask, don't infer)

Profile directory names are chosen at setup time. On this machine:

| profile  | owner        | QQ app id    |
|----------|--------------|--------------|
| (main)   | 用户本人/助手 | 83ECED76… DM |
| `gf`     | 用户本人 (Kubo) | 1905411221 |
| `friend` | 朋友          | 1905582666 |

Confirming the app id is easy: `logs/gateway.log` lines are prefixed
`[QQBot:<app_id>]`, and `inbound message:` lines carry the sender `user=<user_id>`.

## 3. Usage grouped by profile AND by human

```sql
-- per user_id inside one profile DB
SELECT CASE WHEN s.user_id='' THEN '(system/test)' ELSE s.user_id END who,
       u.model, u.billing_provider,
       SUM(u.api_call_count) calls, SUM(u.input_tokens) input,
       SUM(u.output_tokens) output, SUM(u.cache_read_tokens) cache_read,
       MIN(u.first_seen) first_seen, MAX(u.last_seen) last_seen
FROM session_model_usage u JOIN sessions s ON s.id = u.session_id
GROUP BY who, u.model, u.billing_provider
ORDER BY calls DESC;
```

`user_id=''` rows are setup/test traffic — never bill them to the friend.

## 4. When the DB has no numbers, read the logs

A gateway session can hold messages while `sessions.input_tokens`,
`output_tokens`, `api_call_count` are all `0` and `session_model_usage` is
**empty**. Do not report "zero usage" from that alone. Count real calls in the
profile's own logs:

```bash
grep -E "response ready:|Turn ended:|API call failed" \
  ~/.hermes/profiles/<name>/logs/{gateway,agent}.log
```

Signals and what each means:

| log line | meaning |
|---|---|
| `response ready: platform=qqbot chat=… time=… api_calls=N response=… chars` | completed turn, N agent-loop API calls |
| `Turn ended: reason=… api_calls=N/500 …` | turn accounting incl. interrupted turns |
| `API call failed (attempt n/3)` | a provider request that failed; retries cost requests too |
| `API call failed after 3 retries` | the turn burned 3 requests and produced nothing |
| `Codex stream produced no bytes within 120s` | provider stall → TTFB kill → retry loop |

## 5. Worked example — "did my friend's bot burn my GPT quota?"

Asked 2026-09-18 about a QQ bot given to a friend. First answer used the wrong
profile (`gf`, which is the user's own bot) and reported 356 DeepSeek + 55 GPT
calls — the user corrected it.

Correct answer, from `profiles/friend/state.db`:

- `sessions`: 1 session, source `qqbot`, user_id `333D431180983FFA66D086660587FDE4`,
  model `gpt-5.6-sol` (provider `openai-codex`), 2026-09-08 20:10→20:27.
- `message_count = 16` is misleading: `role` counts are 7 assistant / 8 user /
  1 `session_meta`, and the "user" rows are mostly scaffold — an empty-content
  restart notice, a `[file: 补充知识.pptx]` attachment echo, and our own
  post-setup tests ("收到", "阅").
- Real traffic in `gateway.log`: **2** `inbound message:` lines (`hello`, and the
  attachment message). **0** tool calls.
- `session_model_usage` empty; `api_call_count`/token columns 0. `agent.log` shows
  only 2 completed turns (`api_calls=1` each) plus a burst of
  `Codex stream produced no bytes within 120s` TTFB failures and one
  `API call failed after 3 retries` — i.e. the network, not the friend's usage.

Conclusion given: negligible spend; the bot was tested once and not used again.

## 6. Reporting shape the user accepted

- Name the profile path and the owning human explicitly.
- Separate **real inbound messages** from accumulated scaffolding.
- Give the attempt/retry counts, then state plainly whether it is negligible.
- If a previous answer used the wrong profile, say so directly and re-derive —
  do not quietly restate numbers.
