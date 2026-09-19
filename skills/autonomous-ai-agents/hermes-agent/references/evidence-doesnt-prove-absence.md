# Evidence-doesn't-prove-absence — three rules that protect against the same hallucination

Between 2026-09-18 and 2026-09-19 every active agent (Aoi, Kubo, Tomoya)
independently committed the same fallacy: inferring "X is true" from "I
couldn't find evidence that X is false." The list of incidents:

- Aoi, on "are you currently MiniMax?" — checked the session header, did
  not check `agent.log`, answered "yes I am MiniMax." Actual answer was
  `deepseek-v4-flash` because fallback had fired.
- Aoi, on "did the model just switch?" — checked `gateway.log`,
  couldn't find a fallback line, answered "no switch happened." Actual
  answer was `deepseek-v4-flash` because fallback events go through
  `status_callback`, not `logger`.
- Aoi, on "is `<]minimax[>` a server-side protocol leak?" — couldn't find
  the string in the source, concluded "server leaked it." Actual source
  was `chat_completion_helpers.py` constructing it client-side.
- Tomoya, on "is there anything to update?" — saw `package.json` says
  `2026.7.2`, didn't `git fetch` upstream, answered "nothing to update."
  Actual: 9,607 first-parent commits behind.
- Aoi, on "is the upstream repo ahead?" — fetched GitHub API page 2,
  saw 200 commits, answered "barely anything upstream." Actual: 37,686
  unfiltered / 9,607 first-parent.

Common shape in every one: "I looked in N places, didn't find evidence of
X, therefore X is false." Five incidents in one day, three agents,
independent decisions, same error.

This reference defines three rules that block the pattern. They apply to
Aoi, Kubo, and Tomoya — same source, different agents. The rules are
short because the point is that they have to actually load under pressure.

## Rule 1 — "Absence of evidence" needs an explicit ceiling

When you want to say "I checked X and it's not Y," you must name both
the **places you checked** and the **places you did not**. The user, the
auditor, or the next session that picks up the work has to be able to
look at that list and see which absences are evidenced and which are
guesses.

Bad:
```
The model did not switch. (no evidence provided)
```

Good:
```
I checked:
  - gateway.log (logger INFO/WARNING channels)
I did NOT check:
  - status_callback path (which fallback events actually use)
  - agent.log
Therefore: I can only conclude "no fallback was logged via logger." I
cannot conclude "no fallback happened."
```

The "I did NOT check" list is what makes the rule useful. Without it
the model defaults to implying total knowledge.

## Rule 2 — Sample size beats sample content

When you fetch evidence and it returns a small number of records,
**the size of the result is itself a finding.** Don't read the records
and infer what the population looks like.

Bad:
```
I see 200 commits in the GitHub API page-2 result. That looks like
roughly all the recent upstream activity.
```

Good:
```
I see 200 commits across page 1 + page 2 of the API (per_page=100,
default cap). That's at most 2% of upstream's actual commit count
since 2026-08. To get the actual lag I need `git rev-list HEAD..origin/main
--first-parent`.
```

This is the rule that catches GitHub API pagination, log truncation,
list slicing, and "I grepped the codebase and found 5 matches so I think
there are only 5."

## Rule 3 — When the path is unknown, name the path you picked, not the conclusion

When you don't know which log file, function, or config key holds the
truth, say so. **Do not pick one and claim it is the source.**

Bad:
```
The provider switched from M3 to deepseek. (no path cited, user has to
discover the source via follow-up question)
```

Good:
```
I think the provider switched, but I don't know which log records this
event. The places I would check next are:
  1. ~/.hermes/logs/agent.log (where API call #N lines live, with the
     model= field per call)
  2. The status_callback path in run_agent.py:964 (which `_emit_status`
     calls fire on fallback switch)
I will not conclude anything until one of those has been looked at.
```

This is the rule that catches "I checked one log and didn't find it,
therefore the event didn't happen."

## What these rules do NOT change

They do not change the model's taste, its tool access, or the fact that
sometimes a real investigation can't find evidence because the evidence
genuinely isn't recorded. They do force the model to distinguish between
"evidence I checked and was negative" and "I have no evidence."

The distinction matters for the user, who otherwise reads "I didn't find
evidence" as "I checked thoroughly and found nothing." It also matters
for the next agent that picks up the same task — because the missing
"what I did not check" line is exactly the thing that would have
prevented the same hallucination.

## Where the rules came from

The five incidents above all happened in the 24 hours ending
2026-09-19 18:57 CST. They are in this skill because they were expensive
in user time and trust, not because they were theoretically
distinguishable. The skill is here so the next agent that wakes up in a
similar situation — fast-moving conversation, multiple plausible answers,
tight loop between user questions and model guesses — has the rule already
loaded before the user asks the first question.
