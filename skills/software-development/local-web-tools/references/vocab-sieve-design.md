# Vocabulary Sieve — sweep-then-shrink drill design

Reference implementation for 仲耀's 考研英语 tool (`~/projects/yao-vocab-sieve`), built 2026-09.
The user was using 不背单词 and rejected it for one specific reason: **every word got the same study intensity**, so the 6000-word list advanced at a crawl. The whole design follows from inverting that.

## The complaint, in the user's words

> "我想要那种先一次性过完这六千多个单词，然后筛选出不认识和不熟的词，从而逐步减少，而不是认识或者不认识的都按照统一的学习强度"

So: do not schedule "N new words per day". Sweep the entire list once, fast, then spend effort only where it is needed. Each round's list is the previous round's unfinished words.

## Round structure

| Rating | Bucket | Graduation rule |
|---|---|---|
| `1` 认识 | graduates | none — done after the survey round |
| `2` 模糊 | review pool | consecutive `认识` × 2 on later rounds |
| `3` 不认识 | intensive pool | consecutive `认识` × 3 on later rounds |

- Any non-`认识` rating (模糊/不认识) **resets the consecutive streak to zero**.
- A word graduates only by clearing its bucket's streak; the survey round's `认识` is the sole one-shot graduation.
- Round N+1 contains only unfinished words; hardest bucket first, order shuffled inside a bucket.
- `U` undoes the previous judgement — restoring **both** the word's state and the cursor position.

Thresholds 2/3 are deliberately arbitrary and presented to the user as adjustable, not optimal. The correct loop is: he rates a few dozen, then the numbers move.

## Keyboard map (keyboard-first, no mouse needed)

```
space / Enter   reveal the definition
1               认识
2               模糊
3               不认识
u               undo previous rating
s               speak the current word
```

Sidebar (optional, mouse): shuffle toggle, export/import progress JSON, reset. Progress persists in `localStorage` on every keystroke — a session can end mid-word.

## Dataset provenance

- Source: 2027 考研英语红宝书 正序版 structured wordlist.
- Raw entries **6550** → **3** duplicate headwords removed → **6547** usable words.
- Fields kept: headword, Chinese gloss, source page, entry index (page/index shown in the UI so the book can be found).
- Always report raw vs. unique counts; "about 6500" is not acceptable as a verification result.
- License: original copyright remains with the author/publisher. Kept as a private local study tool; provenance recorded in `data/SOURCE.md` and `data/SOURCE-LICENSE.txt` alongside the data. Do not redistribute the wordlist.

## Data shape

```json
{"version": 1, "words": [{"i": 234, "w": "database", "gloss": "n. 数据库", "page": 12}]}
```

Saved state is versioned (`{version: 1, cursor, ratings: {wordId: {state, streak}}, ...}`) with a one-way migration on load, so a schema change never silently wipes weeks of progress.

## Verification that mattered

- 10 `node --test` cases: every bucket, graduation at 2 and 3, streak reset, undo restoring state+cursor, stats split between survey progress and learning buckets, round shrinking, plus artifact-contract tests for `run.sh`/README/`index.html`/count.
- Real Chromium over CDP: title, rendered word, `space` reveals the gloss, `1/2/3` move the counters, `localStorage` matches the DOM after each keystroke, `u` returns to the previous word, zero console errors.
- Screenshot inspected at ~800x600: no overlap or horizontal overflow; the sidebar correctly reflows below the drill area at that width.
- Launcher run twice: second run reused the active `systemd-run` unit instead of starting a second server.
