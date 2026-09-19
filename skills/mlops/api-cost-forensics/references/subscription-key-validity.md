# Is a subscription key actually valid? (and is it even a key?)

Verified 2026-09-19 on this machine while wiring a MiniMax Token Plan key into three
places (Hermes main `.env`, the `gf` profile `.env`, and OpenClaw's sqlite auth store).
Read this before telling a user "the fallback chain is wired".

## 1. Two failure modes that both look fine in a config dump

| Failure | What it looks like | How it was caught |
|---|---|---|
| **Redaction artifact** | 13 bytes: `sk-cp-...atGk` — the *masked* form of the real key, with the same first 5 and last 4 chars | hex-dump of the file: `736b2d63702d2e2e2e6174476b` |
| **Revoked / expired key** | 125 bytes, correct prefix, plausible tail — but 401 on *every* endpoint | live POST returned 401 |

The redaction artifact happens because chat/tool output (including Hermes' own tool
results) masks secrets to **first-5 + last-4**. Copying a key out of a conversation can
therefore copy the *mask* instead of the key — and because the mask preserves the head
and tail, eyeballing two copies side by side proves nothing.

Real length for a MiniMax `sk-cp-` Token Plan key: **124-125 bytes**. Anything under ~40
is a placeholder, not a malformed key.

## 2. The one-command truth check

`scripts/probe-subscription-key.py` (in this skill) does all of it — byte length, masked
view, a live round-trip, and the plan windows:

```bash
# from an .env-style file
python3 scripts/probe-subscription-key.py --file ~/.hermes/profiles/gf/.env --var MINIMAX_API_KEY

# from OpenClaw's sqlite auth store
python3 scripts/probe-subscription-key.py \
  --file ~/.openclaw/state/openclaw.sqlite --sqlite-key minimax:default
```

Exit code 0 = the key authenticated. Use it for every copy of a key on the box, because
**two copies with identical head/tail can still be one real key and one placeholder.**

## 3. MiniMax endpoint facts (2026-09)

| Purpose | Call |
|---|---|
| Provenance check (needs key) | `GET https://api.minimax.io/v1/models` with `Authorization: Bearer <key>` |
| Windows | `GET https://api.minimax.io/v1/token_plan/remains` with `Authorization: Bearer <key>` |
| Real generation | `POST https://api.minimax.io/anthropic/v1/messages` — `x-api-key: <key>` + `anthropic-version: 2023-06-01` |

- A dead key 401s on **all three**, including the ones that make no model call:
  `login fail: Please carry the API secret key in the 'Authorization' field of the request header (1004)`.
  So "the key is at least accepted by /v1/models" is not a weaker-but-valid state — it's
  either accepted or not.
- `/v1/token_plan/remains` → `model_remains[0]` carries
  `current_interval_remaining_percent` (5h window) and `current_weekly_remaining_percent`
  (weekly window) plus `start_time` / `end_time` / `weekly_start_time` / `weekly_end_time`.
  **The count fields read `0/0` even on working keys** — trust the percent fields only.
- Observed on a working key, 5h/week windows reset independently of each other; a probe
  right after a reset reads ~99-100%.
- `max_tokens: 16` was enough for `MiniMax-M3` (returned 5 output tokens plus
  `cache_read_input_tokens: 128`, i.e. prompt caching is active).
- `/v1/user/balance` is **404** here — that is a Moonshot endpoint, not MiniMax. Don't
  read a 404 as "key broken".

## 4. Reporting rule

Before saying a provider/fallback integration is done:

1. Every copy of the key on the box passes the probe (per file, not "the same key").
2. The runtime that will use it has been restarted (`.env` is read at process start;
   OpenClaw caches its auth store at gateway startup).
3. A real message/turn has exercised the hop — or say plainly that step is still pending.

Saying "configured" on the strength of config text is how this session misreported twice.
