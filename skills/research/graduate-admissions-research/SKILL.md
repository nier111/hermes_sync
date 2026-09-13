---
name: graduate-admissions-research
description: "Use when comparing graduate admissions programmes and risk."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [research, admissions, graduate-school, score-lines, programme-comparison]
    category: research
    related_skills: [grounded-citations, blocked-page-recovery]
---

# Graduate Admissions Research

Use this skill when a user needs to choose among graduate schools, colleges, programmes, directions, campuses, or examination subjects. The deliverable is an evidence-backed decision aid, not a list of copied score lines.

## Core principle

Admissions data has several incompatible denominators. Normalize the cohort, programme, study mode, quota type, and candidate population before comparing any numbers.

A useful recommendation must combine:

- official admissions rules and current publication status;
- prior-year score lines, quotas, and admitted-score distributions;
- exam-subject continuity and switching cost;
- programme/research fit with the user's real coursework and projects;
- volatility from small cohorts, special plans, and joint-training allocations;
- geography, campus, tuition, housing, and employment constraints.

## Required workflow

### 1. Resolve the admissions year

Write down all three dates explicitly:

1. registration year;
2. initial-exam year;
3. intended entry/cohort year.

Chinese admissions discussions often call the latest completed cohort “last year” even though registration and the written exam occurred in the preceding calendar year. Never silently mix calendar-year and cohort-year labels.

Check the live official catalogue before relying on last year's data. If the new catalogue is not yet open, say so near the top and label every programme, subject, and quota as provisional.

### 2. Recover existing user research first

Before searching from scratch:

- search prior sessions for the institution, programme codes, subject codes, and earlier recommendations;
- search the user's study/research directories for saved catalogues, score-line tables, re-exam notices, and admitted lists;
- treat those files as leads, then check whether the official live source has changed.

This prevents the user from having to repeat earlier research and lets new findings update rather than overwrite prior work.

### 3. Build a normalized candidate table

For each option, collect these fields separately:

| Field | Why it matters |
|---|---|
| School/college code and name | Similar names can hide different admissions units |
| Programme code/name and direction code | Cutoffs and subjects may differ by direction |
| Full-time/non-full-time | Do not combine their quotas or outcomes |
| Campus/training location | Affects cost and willingness to attend |
| Initial-exam subjects | Same programme name may use a different paper by college |
| Re-exam written subject | Determines post-exam switching cost and project fit |
| Catalogue planned intake | Often includes recommended admission, special plans, etc. |
| Public-exam quota | The useful denominator for ordinary exam candidates |
| Score line and subject minimums | Entry threshold, not a safe target |
| Actual admitted count and score distribution | Shows the real competitive band |
| Special-plan flags | Low-score outliers may not belong to ordinary competition |
| Joint-training rules | Can change location, supervisor, or training unit |

Never merge “catalogue planned intake” with “public-exam quota.” Label both whenever both exist.

### 4. Use a source hierarchy

Prefer, in order:

1. official current-year catalogue and admissions regulations;
2. official school-wide score-line and re-exam policy pages;
3. official college re-exam notices;
4. official admitted-list attachments;
5. official historical tables;
6. third-party analyses only for gaps, clearly labelled as secondary.

A search-result snippet can locate a removed page, but it should support only what the snippet literally states. Do not promote a cached snippet or forum summary to the status of an official attachment.

For a cited report, load `grounded-citations`, register sources while retrieving them, and run citation verification before delivery.

### 5. Recover and verify official attachments

University sites commonly expose attachments in several ways:

- embedded PDF viewer: inspect `iframe`, `embed`, or `object` and retrieve the direct `file=` or `/__local/...pdf` URL;
- download handler: inspect the attachment anchor for `DownloadAttachUrl`, owner, and file ID;
- CAPTCHA-protected download: open the handler in a real browser, complete the ordinary verification, enable browser downloads, and save the resulting file;
- removed announcement: search the college listing and official historical page, but do not invent the lost attachment URL.

After every download, verify the artifact before parsing:

```bash
file document.pdf
pdfinfo document.pdf
```

A file named `.pdf` may actually be an HTML browser-check page. Never feed it into statistics or describe it as a PDF until the MIME/type check passes.

### 6. Parse lists mechanically

Use `pdftotext -layout` or document extraction, then script the aggregation. Do not count rows or estimate medians by eye.

At minimum calculate per exact programme/direction/study mode:

- count;
- minimum;
- median;
- mean;
- maximum.

Then inspect and separate:

- special plans;
- non-full-time candidates;
- transfers/adjustments;
- direction codes;
- records below the ordinary score line.

A low admitted score is not automatically an ordinary-candidate minimum. Check the remarks column and the scoring formula.

### 7. Interpret the data rather than ranking by cutoff

Use at least three years of score lines when available, but do not extrapolate them linearly. A sharp rise may reflect a previously discovered “low-score valley,” quota changes, paper difficulty, or applicant migration.

Distinguish:

- **threshold**: the re-exam line;
- **observed competitive band**: preferably median and central range of admitted initial scores;
- **planning target**: a conservative recommendation that also accounts for re-exam weight and user readiness.

If initial and re-exam scores are weighted equally, emphasize that a near-line admit may have relied on an exceptional re-exam. The minimum admitted score is therefore not a safe target.

Small cohorts are volatile. A direction admitting eight people can swing far more than one admitting hundreds, even if its last score line was lower.

### 8. Make the recommendation user-specific

Do not stop at “Programme A has a lower line.” Compare:

- current exam preparation and the cost of changing papers late;
- relevant projects that can become credible interview evidence;
- re-exam subject readiness;
- realistic recent mock-test range;
- willingness to accept another campus or joint training;
- preference for research, embedded engineering, circuits, algorithms, or employment.

Give a clear default recommendation, then distinguish:

- balanced/default option;
- high-fit but volatile option;
- geographical alternative;
- high-score reach option;
- conditional option that requires changing exam subjects.

Do not overwhelm the user with every technically possible college. Explain why the non-priority options were filtered out.

### 9. Deliver and preserve the result

A good deliverable contains:

1. cohort/date caveat;
2. compact normalized comparison table;
3. explicit ranked recommendation;
4. risks and conditions that could change the ranking;
5. official-source links;
6. a saved report and downloaded source files when local storage is available.

Verify any saved report's citations and statistical calculations before claiming completion.

## Pitfalls

- **Calendar-year confusion:** “2026 admissions” may involve a 2025 written exam and 2026 entry.
- **Same programme name, different paper:** compare college + programme + direction, never name alone.
- **Quota denominator error:** catalogue intake may include recommended admission and special plans.
- **Minimum-score fetish:** one excellent re-exam or special-plan candidate can produce a misleading minimum.
- **Small-cohort false safety:** a low cutoff with eight places is not necessarily safer than a higher cutoff with fifty places.
- **WAF/challenge contamination:** obfuscated JavaScript pages may contain accidental subject-code strings. Only parse rendered admissions content, not challenge scripts.
- **Extension trust:** `.pdf` filenames returned by `curl` can contain HTML; verify type first.
- **Third-party certainty:** use third-party statistics only when official attachments are unavailable, and label the weaker provenance.
- **Premature subject switching:** do not recommend changing a prepared exam paper until the new official catalogue and syllabus are published and the switching workload is compared chapter by chapter.

## Verification checklist

- [ ] Cohort year and calendar-year timeline are explicit.
- [ ] Current official catalogue availability was checked.
- [ ] Programme, direction, study mode, and campus are not conflated.
- [ ] Catalogue intake and public-exam quota are labelled separately.
- [ ] Downloaded attachments passed type/integrity checks.
- [ ] Counts and statistics were computed by script.
- [ ] Special-plan and non-full-time outliers were considered.
- [ ] Cutoff is not presented as a safe score.
- [ ] Recommendation reflects exam-switching cost and user fit.
- [ ] Source citations were verified.

## Case references

- See `references/uestc-2026-to-2027.md` for a condensed example of dynamic catalogues, embedded PDFs, CAPTCHA downloads, and score normalization at the University of Electronic Science and Technology of China.
