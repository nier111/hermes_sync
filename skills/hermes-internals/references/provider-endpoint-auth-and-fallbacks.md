# Provider endpoint auth routing — why a "correctly configured" primary still falls back every turn

Companion to `references/model-fallback-forensics.md`. That file answers *"which model answered
this turn?"*. This one answers the question that usually follows: *"the primary is configured,
so why does it never answer?"*

## The rule: `base_url` decides which auth header Hermes sends

`~/.hermes/hermes-agent/agent/anthropic_adapter.py` → `_requires_bearer_auth(base_url)` returns
True for **only** these hosts:

```text
https://api.minimax.io/anthropic
https://api.minimaxi.com/anthropic
<anything>.azure.com
*.palantirfoundry.com            (hostname match, not substring)
Nous Portal Messages route
```

For those, Hermes sends `Authorization: Bearer <key>` instead of Anthropic's native
`x-api-key`. MiniMax's Anthropic-compatible endpoints **reject `x-api-key`**, so a `base_url`
that is not on that whitelist — e.g. `https://api.minimax.cn/anthropic` — makes Hermes send the
wrong header:

```text
config base_url = https://api.minimax.cn/anthropic
   → _requires_bearer_auth() False   (the .cn host is NOT in the whitelist)
   → Hermes sends  x-api-key: <key>
   → MiniMax rejects with 401
   → every turn falls back to fallback_providers[0]
   → provider console shows ~0% of the plan consumed
```

`_is_minimax_anthropic_endpoint()` uses the same two hostnames, and separately strips the
fine-grained-tool-streaming / context-1m betas that MiniMax refuses.

Verify the rule still lives there before quoting it as fact (whitelists drift):

```bash
grep -n -A14 "_requires_bearer_auth\|_is_minimax_anthropic_endpoint" \
  ~/.hermes/hermes-agent/agent/anthropic_adapter.py | head -60
```

Fix and confirm:

```bash
hermes config set model.base_url "https://api.minimaxi.com/anthropic"
hermes config get model.base_url
```

**Do not call this "verified" until a turn actually lands on the primary.** The Hermes-side
requirement (host must match the whitelist) is a source fact; whether *this user's key* is valid
on the whitelisted host is a separate provider-side question. Two-sided risk to state honestly:
a host outside the whitelist means the wrong auth header; a host the key isn't scoped to means
401 for a different reason. Confirm with banner-absent + a growing `session_model_usage` row for
that model, not with optimism.

## Diagnostic signature: "primary always fails, quota untouched"

The user's own observation is the tell — *"the console says only 10% used, but you're answering
as a different model."* That combination (plan barely consumed + replies are the fallback) points
at a config/routing defect, not at quota. Discriminate the three candidates:

| Candidate | On-disk evidence |
|---|---|
| primary真正不可用 (5xx / timeout) | `Primary provider rate-limited (429)` / connection-error lines in `logs/gateway.log` naming the primary |
| wrong auth header (this file) | primary never logs a success; provider console near-0%; `base_url` host not in the whitelist above |
| per-turn override | `Runtime provider supplied explicit model override: A -> B` in `logs/gateway.log` |

## Where the banner text travels vs where the log lines live

Verified emission path for `🔄 Switched to fallback model: A via p1 → B via p2`:

```text
agent/chat_completion_helpers.py   _pending_fallback_notice = ...        (string built here, one place)
agent/run_agent.py                 _emit_pending_fallback_notice()  →  _emit_status(notice)
agent/run_agent.py  _emit_status   →  _vprint(force=True)          (CLI)
                                   →  status_callback("lifecycle", msg)  (gateway → platform banner)
```

So the **banner string** travels a *status-callback* channel, while the diagnostic lines
(`Primary provider rate-limited`, `Fallback provider resolved`, `Runtime provider supplied
explicit model override`) are ordinary `logger.*` lines that **are** greppable in
`logs/gateway.log`. Consequence for reasoning:

```text
"the exact banner text isn't in gateway.log"  ≠  "no switch happened"
```

Grep the trio (see the forensics reference), never the banner string, when deciding what
answered. `_buffer_status` also defers retry chatter and only flushes it when retries are
exhausted — so retry noise legitimately appears later than the event it describes.

## Probing a provider endpoint: hand the user a curl probe

The agent-side executor hard-blocks "read a plaintext key + make an outbound HTTP request"
(consent does not clear it, and rephrasing or switching tools is forbidden). Don't burn turns
arguing with it — hand the user a copy-paste probe and read their output:

```bash
KEY=$(grep '^MINIMAX_API_KEY=' ~/.hermes/.env | cut -d= -f2-)
curl -sS --max-time 15 https://www.minimax.cn/v1/token_plan/remains \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' | head -c 600
echo
curl -sS --max-time 30 https://api.minimaxi.com/anthropic/v1/messages \
  -H "Authorization: Bearer $KEY" -H "anthropic-version: 2023-06-01" \
  -H 'Content-Type: application/json' \
  -d '{"model":"MiniMax-M3","max_tokens":32,"system":"Reply OK.","messages":[{"role":"user","content":"hi"}]}' \
  | head -c 800
```

Ask for the HTTP status codes and the first lines of each — that distinguishes wrong-header
(401/403) from quota (429) from a working primary (200), which is what the whole question
turns on.
