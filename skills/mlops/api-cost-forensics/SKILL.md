---
name: api-cost-forensics
description: "Investigate unexpected LLM API spend/billing (DeepSeek etc)."
---

# API cost forensics

## Trigger
- User alarmed by an LLM API bill ("today cost X元", "more than the pro days"),
  sudden spend spike, or "what is burning my tokens?" questions.

## Where Hermes usage is recorded
- Default profile: `~/.hermes/state.db` → table `session_model_usage`
  (per session+model+provider: api_call_count, input/output/cache_read/
  reasoning tokens, estimated_cost_usd, actual_cost_usd). actual_cost is often
  0 — estimates only.
- EVERY profile has its OWN state.db: `~/.hermes/profiles/<name>/state.db`
  (e.g. the gf/Kubo profile). Check each — they are separate stores.
- Pricing used for estimates: `~/.hermes/models_dev_cache.json` → cost object
  per provider (deepseek-v4-flash: input $0.14/M, output $0.28/M,
  cache_read $0.0028/M).
- Pre-update snapshot dbs: `~/.hermes/state-snapshots/`.

## Daily totals (sqlite3)
```
SELECT date(s.started_at,'unixepoch','localtime') day,
 COUNT(DISTINCT u.session_id) sess, SUM(u.api_call_count) calls,
 SUM(u.input_tokens) inp, SUM(u.cache_read_tokens) cr, SUM(u.output_tokens) out,
 ROUND(SUM(u.estimated_cost_usd)*7.2,2) cny
FROM session_model_usage u JOIN sessions s ON s.id=u.session_id
GROUP BY day ORDER BY day;
```
Use ~7.2 CNY/USD for rough 元. Run the same query on each profile's db.

## Cross-check against the provider platform
- DeepSeek platform (platform.deepseek.com/usage): cumulative cost/tokens/
  requests, per-day bars. Hovering a bar shows exact daily breakdown:
  Input (Cache hit) / Input (Cache miss) / Output.
- Observed: hermes UNDERCOUNTS cache-hit tokens vs the platform (8/6 case:
  hermes ~99M vs platform 180M cache hit) — real cost ≈ 1.8-2.3x hermes estimate.
- Platform history can predate the current state.db (install/records start
  later) — cumulative totals include usage from before records exist.
- Platform request counts ≠ hermes api_call_count (one hermes turn can make
  several HTTP requests; the platform counts HTTP requests).

## Finding WHO uses the key
- Scan all processes for the key in env (boolean, redacted):
  `tr '\0' '\n' < /proc/<pid>/environ | grep -c '^DEEPSEEK_API_KEY='`
- hermes reads keys from ~/.hermes/.env WITHOUT exporting to process env — an
  env scan misses key users that READ files. Each profile has its OWN key file.
- Identify unknown hosts behind IPs via TLS SNI:
  `echo | openssl s_client -connect <IP>:443 -servername <suspected-host> 2>/dev/null | openssl x509 -noout -subject`
  (e.g. proved a "DeepSeek-looking" IP was actually *.ias.tencent-cloud.net).
- Browser extensions can hold API keys (Immersive Translate supports DeepSeek)
  in chrome.storage LevelDB — strings scan may miss Snappy-compressed blocks,
  so a negative result is inconclusive.
- OpenClaw ships provider extensions (deepseek enabledByDefault) but needs a
  configured key to make calls.

## Pitfalls
- estimated_cost_usd ≠ bill; platform numbers are ground truth for totals,
  hermes db for per-session/per-model attribution.
- If attribution is still unresolved, get the platform's Model / API Key tab
  breakdown (per-model or per-key usage) BEFORE concluding — do not fabricate
  a culprit from partial evidence.
