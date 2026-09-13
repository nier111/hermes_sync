# DeepSeek balance vs. subscription quota, and the context-cost multiplier

Companion to the main skill. Use when the user says "额度用完了" / "my quota is
gone" — the first job is to find out *which* pool is actually exhausted.

## Live balance check (ground truth, one cheap call)

```sh
KEY=$(grep -m1 '^DEEPSEEK_API_KEY=' ~/.hermes/.env | cut -d= -f2- | tr -d '"')
curl -s --max-time 20 https://api.deepseek.com/user/balance \
    -H "Authorization: Bearer $KEY"
```

```json
{"is_available":true,
 "balance_infos":[{"currency":"CNY","total_balance":"21.98",
                   "granted_balance":"0.00","topped_up_balance":"21.98"}]}
```

- `is_available: true` with a non-zero balance means the DeepSeek account is
  **not** the thing that ran out.
- Hermes reads keys from `~/.hermes/.env` per profile; it does not export them
  into the process environment, so an env scan misses them. Never echo the key.

## The two different pools people conflate

| Pool | Exhausts as | Visible where |
|---|---|---|
| ChatGPT Plus / Codex subscription | a **rate/usage limit**, no money | Codex or ChatGPT UI; Hermes just silently falls back |
| DeepSeek API account | **money** (balance) | `/user/balance`, platform usage page |

When `model.default` is a subscription model with `fallback_model: deepseek-*`,
a subscription limit shows up as "the model changed to deepseek", which is easy
to misread as "the API key ran dry". Check the balance before diagnosing.

Useful config to quote back:

```sh
grep -nE '^(model|fallback_model)|^  (default|provider|model):' ~/.hermes/config.yaml
```

## The real driver: context re-sent on every call

Per-session attribution (default profile DB):

```sql
SELECT substr(u.session_id,1,22) sid, SUM(u.api_call_count) calls,
       SUM(u.input_tokens) inp, SUM(u.cache_read_tokens) cr,
       SUM(u.output_tokens) out,
       ROUND(SUM(u.estimated_cost_usd)*7.2,2) cny
FROM session_model_usage u JOIN sessions s ON s.id=u.session_id
WHERE date(s.started_at,'unixepoch','localtime')=date('now','localtime')
GROUP BY u.session_id ORDER BY cny DESC LIMIT 5;
```

Diagnostic worth computing out loud:

```
context re-sent per call  ~=  SUM(cache_read_tokens) / SUM(api_call_count)
```

A long-running session with heavy tool output can reach ~150K tokens of context
per call. Then a single request looks enormous even though each individual turn
is cheap — the multiplier is the **history**, not the prompt. Trailing
`cache_read_tokens` are cheap per token but still billed, and the estimate can
undercount cache hits by roughly 2x versus the platform page.

## Advice that actually reduces spend

1. **Start a fresh session** once a task reaches a natural breakpoint: persist
   state to files first (README, tests, notes), then continue in a clean context.
   This is the single biggest lever for a long conversation.
2. Move mechanical work (file shuffling, batch parsing) to local scripts or a
   separate CLI agent instead of the main model loop.
3. Only then consider switching the main model — and prefer shortening context
   over swapping providers.

## Pitfalls

- `estimated_cost_usd` is an estimate, not the bill; the platform usage page is
  the ground truth for totals, the local DB for per-session attribution.
- Pre-update snapshots live in `~/.hermes/state-snapshots/`; records may start
  later than the platform's cumulative history.
- Each profile has its **own** `state.db` — check `~/.hermes/profiles/<name>/`
  before declaring a total.
