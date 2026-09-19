# Pre-update check — never say "nothing to update" without running it

The user will sometimes ask "is there anything to update?" or "should we
update?" The default answer to that is a guess. A guess here costs real
progress: in 2026-09 a 34-day Hermes stall and a 9,607-commit upstream gap
were both misjudged as "nothing meaningful" because nobody ran the actual
check before answering. This reference defines the only acceptable way to
respond to that question.

## The mandatory 3-step check

Run all three before forming any verdict. Do not skip the diff-stat step
"to save time" — that is the whole point.

```bash
cd /home/sato/.hermes/hermes-agent   # or the relevant repo root

# 1. Where is the remote pointing? Confirm it's the actual upstream.
git remote -v
git config --get-all remote.origin.url

# 2. Fetch fresh (slow on first run; the network call is unavoidable).
git fetch origin main --quiet

# 3. Count, with first-parent so merge commits don't inflate the number.
git rev-list --count HEAD..origin/main --first-parent
# Optional: also report the unfiltered count for context
git rev-list --count HEAD..origin/main

# 4. Title sample (first 30) so you can name what is actually pending.
git log HEAD..origin/main --oneline | head -30
```

After running these, you may answer the user. Before running them, you
must not.

## Why first-parent and not the raw `..` count

`git rev-list A..B` walks every commit reachable from B that is not
reachable from A. For a busy repo with `--no-ff` merge commits (Hermes and
OpenClaw both use this), the side-branch tips that were merged into main
are *still reachable from main*, so they get counted **twice** — once at
their merge commit, once as themselves.

The 2026-09-19 incident: a delegate reported `rev-list` showing **37,686
commits behind**. The main agent questioned the number, ran the same
command itself, and got the same answer. The right reflex was not to
question the number — it was to question which number to report.

`first-parent` walks only the main history line, so the number maps to
"how many direct commits have landed on upstream's main that we haven't
brought into ours." That is the operationally meaningful number.

## Things you must NOT infer from this

- "37,686 sounds too big, must be a mistake" — see above.
- "Only 200 commits returned by the GitHub API page, so we're roughly
  current" — the API default is 100 per page, you only saw the head of the
  iceberg.
- "git log HEAD..origin/main --grep anthropic | head -5 returned nothing,
  so no upstream commit touches the anthropic provider" — `--grep` only
  finds *titles* containing the keyword, not commits whose diff touches the
  area. Use `--all` plus file-path match, or just look at the title sample.
- "We made a local fix at bab7be3, upstream surely has it" — almost
  certainly yes, but confirm via `git log bab7be3..origin/main --grep
  <relevant keyword>` rather than assume.
- "No relevant fix in the top 30 commit titles, so nothing to update" —
  same as above. Sample size. Use first-parent count + targeted grep across
  the full range for the keyword, or do `git log HEAD..origin/main --grep
  '<keyword>' | wc -l` to actually count.

## When to recommend `hermes update` (or `pnpm openclaw update`)

Default to recommending update when **any** of these is true:

1. `first-parent` lag > 100 commits and there are `--fix` or `--feat`
   commits in the title sample that touch a hot path the user has touched in
   the last 30 days (providers, gateway, anthropic adapter, QQ/Telegram
   adapter, cron, fallback chain, model picker, env loader).
2. The user explicitly mentions a behavior that matches a known upstream
   fix from `git log HEAD..origin/main --grep <symptom>` — even if the
   top-30 title sample doesn't show it.
3. A bug was just diagnosed as "we don't have the patch that fixes it" —
   patch the upstream fix is in the title sample.

Default to **not** recommending when:

- `first-parent` lag is 0.
- `first-parent` lag is small (<10) and the title sample shows only
  `chore:` / `docs:` / `test(refresh)` commits.

When in doubt, lean toward update. The cost of an unnecessary update is a
brief gateway restart; the cost of missing a real fix is silent breakage
that surfaces weeks later as a "weird behavior" with no obvious cause.

## Update procedure (when the user agrees)

Hermes has the `hermes update` command which performs a self-update and
restarts the gateway. Local working-tree changes will conflict; either
back them up first or accept losing them.

```bash
# Optional but recommended: backup local working-tree changes.
git diff > /tmp/hermes-local.patch

# Optional: stash them so the update is clean.
git stash push -u -m "pre-update"

# Run the update.
hermes update
# ... gateway restarts here ...

# If the update succeeded but you want the local changes back:
# git stash pop
# If you don't:
# git stash drop
```

OpenClaw has the analogous `pnpm openclaw update --yes` flow.

Never run either `hermes update` or `pnpm openclaw update` without an
explicit "yes, update now" from the user — system restart breaks the
active QQ session mid-conversation. This requirement is not policy, it is
physics.

## Pitfalls

- The `git fetch` may time out the first time on a slow connection. The
  60s budget is sometimes not enough; use `--timeout=180` and retry once.
- The `git fetch` may have already been done in the same session — check
  `.git/FETCH_HEAD` mtime before re-fetching so you don't waste 60s on a
  no-op.
- `git remote -v` may print stale URLs if `git remote set-url` was run
  without a follow-up fetch. If the URL looks wrong, say so and ask
  before doing anything else.
- The OpenClaw `~/.openclaw/openclaw.json` config dir is *not* touched by
  `git pull` — it lives outside the source repo. Do not infer "my config
  will be wiped" from `git pull` activity.
