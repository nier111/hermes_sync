# The approval gate — why a tool call returns "the user has NOT consented"

Read this when `execute_code` / `terminal` returns
`BLOCKED: ... The user has NOT consented to running this code`, especially on a
messaging platform (QQ / Telegram / Discord), and especially when the user *did*
type something like "同意" in chat. Companion to
`references/provider-endpoint-auth-and-fallbacks.md` (which carries the curl-probe
handoff this file recommends).

## Where the gate lives

`~/.hermes/hermes-agent/tools/approval.py`.

The `execute_code` path (~L5040-5080) funnels every call through:

```python
decision = _await_gateway_decision(
    session_key, notify_cb, approval_data, surface="gateway"
)
```

So the decision is **not** read from the conversation. It comes back from the
platform's approval surface (an inline card / notification the user has to act on).
Prose typed into the chat never enters this variable.

## The three outcomes, and their exact strings

| Situation | Returned message fragment | Meaning |
|---|---|---|
| card could not be delivered | `BLOCKED: Failed to send execute_code approval request to user. Do NOT retry.` | transport problem, the user was never asked |
| nobody answered in time | `BLOCKED: execute_code script timed out without user response. ... Silence is not consent.` | the question was asked, no click arrived |
| explicit refusal | `BLOCKED: ... denied by user. Reason given by the user: "..."` | the only variant that is actually about user intent |

Only the third variant is evidence about what the user wanted. The first two are
infrastructure outcomes, and the shared tail wording
(`The user has NOT consented ...`) belongs to the gate, not to the user.

There is also `_denial_breaker_addendum(session_key)` — repeats escalate. And a
`smart_denied` path (`_prepare_smart_approval_observer` /
`_observe_smart_approval_verdict`, hooks `pre_approval_request` /
`post_approval_response`, `decided_by="aux_llm"`) in which an auxiliary LLM, not
the user, produced the verdict. Source-read fact — verify before quoting if the
diagnosis depends on it.

## What trips the gate

The recurring pattern is a single script that **reads a plaintext credential and
makes an outbound network request** — e.g. pulling an API key out of `~/.hermes/.env`
with a regex and then calling `https://...`. Reading the file alone, or calling out
without a credential, is usually fine. The combination is what escalates.

## Handling it correctly

1. **Classify before explaining.** Match the exact string against the table above.
   Saying "you didn't agree" to a user who just typed their agreement is a real
   error — it converts a delivery failure into an accusation.
2. **Do not retry, rephrase, or reroute.** The block text itself says: do not retry,
   do not rephrase the script, do not attempt the same outcome via a different tool.
   Re-issuing them through `terminal` looks like circumventing a security boundary.
3. **Switch to a human-in-the-loop probe.** Hand the user one copy-paste command and
   read their output (see the curl block in the auth reference). This is the fastest
   path and it is not a workaround.
4. **Or remove the credential from the script entirely** — have the user store it in
   `~/.hermes/.env` and drive a normal tool path that does not hand-assemble a key.
5. If a card *should* have appeared and did not, that is a platform/transport bug
   worth reporting, not something to solve by trying harder from the agent side.

## Pitfalls

- On click-only platforms a correct config can still be unusable: the gate exists,
  the user is willing, and there is no surface to press. Diagnose that, do not
  re-litigate consent.
- Do not tell the user the executor "ignores explicit authorization" as a general
  rule. What it ignores is *chat text as authorization*; the card is the channel.
- A blocked attempt consumed nothing — the request never left the machine. That is
  useful evidence when the user is also tracking provider-side quota.
