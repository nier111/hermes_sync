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

## Batch-first interaction (current implementation)

The survey must reduce user actions, not merely place several independent single-word cards on one screen:

- Default page size: **8 words**, adjustable to 4 / 8 / 12.
- Every unmarked word is treated as `认识` when the page is submitted.
- The user only marks the exceptions (`模糊` / `不认识`), then submits the whole page once.
- Clicking a word toggles its definition; each card has its own pronunciation button.
- `Enter` submits the page; `U` undoes the entire previous page, including after focus remains on the submit button.
- A batch is persisted to SQLite transactionally. Undo restores every affected word and deletes only that batch's attempt rows; it must not replace or truncate older attempt history.

This is materially faster than showing 4–8 cards while still requiring one rating action per word.

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

- Pure-logic and artifact tests cover all rating buckets, 2/3-streak graduation, streak reset, batch submission, whole-page undo, local launcher and UI contract.
- SQLite tests cover atomic batch writes and atomic page undo without deleting older history.
- Real Chromium over CDP: eight cards render, clicking a word reveals its gloss, two exception marks plus one submit move progress by eight, SQLite counters match, `U` returns all counters and rows to the exact pre-test state, and console errors remain zero.
- Compare the live database against a pre-test SQLite backup after undo (`word_progress`, `attempts`, queue/cursor/round/phase): zero row differences.
- Screenshot at desktop viewport: inspect all eight cards, exception highlighting, controls, horizontal overflow and clipping.
- Launcher run twice: second run reuses the active `systemd-run` unit instead of starting a second server.
