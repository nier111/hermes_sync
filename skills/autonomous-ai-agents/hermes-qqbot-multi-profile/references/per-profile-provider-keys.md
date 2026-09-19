# Per-profile provider keys and fallback chains

Verified 2026-09-19 while putting `minimax` into the fallback chain of **both** QQ bots
(profile `default`/Aoi and profile `gf`/Kubo). Read this before adding a provider or a
fallback hop to a bot profile.

## The rule that caused two rounds of wrong reporting

**A profile has its own `.env`.** `~/.hermes/.env` (the default profile) does NOT apply to
`--profile gf`. Each profile needs the key written into
`~/.hermes/profiles/<name>/.env`, and the gateway for that profile must be restarted
before it is read.

I reported the chain as "wired" while the `gf` `.env` actually contained a **13-byte
redaction artifact** (`sk-cp-...atGk`, literally the masked display form of the working
key, hex-confirmed `736b2d63702d2e2e2e6174476b`) — same first 5 and last 4 characters as
the real key. The user had to catch it ("你没有配置正确的 minimax api key，是被缩减后的，只有13个字符").
Config text is not evidence; an authenticating key is.

## Verification steps (run per profile, per key file)

```bash
# 1. raw byte length — a real MiniMax sk-cp- key is 124-125 bytes; 13 means placeholder
python3 -c "print(len([l for l in open('$HOME/.hermes/profiles/gf/.env') if l.startswith('MINIMAX_API_KEY=')][0].split('=',1)[1].strip()))"

# 2. live round-trip through the actual endpoint
python3 ~/.hermes/skills/mlops/api-cost-forensics/scripts/probe-subscription-key.py \
  --file ~/.hermes/profiles/gf/.env --var MINIMAX_API_KEY      # exit 0 = usable

# 3. chain shape for that profile
hermes --profile gf fallback list
```

Then, and only then, restart that profile's gateway
(`hermes-gateway-<name>.service`) and exercise a real message so the hop actually fires.
Until a fallback has fired once, say it is *configured but unexercised* — not "working".

## Why the mask comparison is meaningless

Hermes tool output masks secrets to **first-5 + last-4**, so a shortened copy and a real
key look identical in any dump you read. Never conclude "same key" from head/tail; use
byte length from the file plus a live call.

## Fallback economics for subscription keys

A `sk-cp-` key is a **subscription window**, not pay-as-you-go. Putting it in the middle
of a chain (`primary → subscription → PAYG`) is self-limiting and reasonable: a drained
window 429s and Hermes cascades to the next entry. But it burns fast on long sessions
(cache_read accumulates every turn), so keep a cheap PAYG model as the last hop and check
the windows before assuming there is headroom:

```bash
python3 ~/.hermes/skills/mlops/api-cost-forensics/scripts/probe-subscription-key.py --key "$KEY"
# prints 5h and weekly remaining percent
```

See `api-cost-forensics` → `references/cn-token-plan-quota-verification.md` for plan
pricing/limits and the rule about never promising durability.

## Related

- `references/gateway-restart-and-handshake.md` — what a real profile gateway restart means.
- `references/bot-ownership-and-usage-attribution.md` — which bot burned which quota.
