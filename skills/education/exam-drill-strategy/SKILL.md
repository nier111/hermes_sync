---
name: exam-drill-strategy
description: "Use when judging if more problem drilling is worth it."
version: 1.0.0
author: Aoi
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [study, exam-prep, problem-sets, triage, textbook, kaoyan]
    category: education
    related_skills: [terminal-math-tutoring, study-recall-materials, graduate-admissions-research]
---

# Exam Drill Strategy

Use this skill when the question is really *"do I still need to keep doing this?"* rather than *"explain this to me"*:

- "第三章快做一半了，感觉就是同一套性质反复用，还有必要做完吗？"
- "题太多了，要不要全做？"
- "要不要换一本习题集 / 换一本教材？"
- "什么时候开始刷真题？"
- "我这本资料含金量够不够？"

The deliverable is a **decision plus a concrete next action**, not an essay about the value of hard work.

## Core principle

Volume is not coverage. The unit of study value is a *distinct route or trap*, not a problem.

```text
Distinct value:  new structure | new property combination | new failure mode
Low value:       same route, different numbers / widths / coefficients
```

Once a template is recognized, extra instances buy **fluency**, not understanding. Both are real — fluency is what makes a calculation-heavy paper survivable — so the honest verdict is usually "keep some, stop the repetition", never "keep all" and never "this book is useless".

Recognize the learner's signal: when they spontaneously say "怎么又是同一套", that is emerging pattern recognition, not laziness. Reward it by giving them a stopping rule; do not argue them back into finishing for completion's sake.

## Required workflow

### 1. Anchor to the user's real position

Do not answer abstractly. Establish:

- which resource, which chapter, how far in;
- what the target exam actually requires from that material;
- how much calendar time remains and what else is unfinished (other chapters, other subjects).

An opinion about a textbook is worthless without knowing the user is halfway through chapter 3 with four subjects left.

### 2. Verify the resource's status before agreeing or disagreeing

Check authoritative sources, in this order:

1. official reference-book page for the subject (the school's own 参考书目);
2. official syllabus / 考试大纲 for declared scope;
3. official past-paper subject-relevance notes;
4. third-party experience posts and course-seller write-ups — secondary only.

Two traps here:

- An official listing is **not** a per-problem mandate. One subject may officially list several books at once; the school is describing a knowledge system, not assigning every exercise.
- Experience posts claiming "真题大量改编自某书例题与课后题" are usually 学长回忆 or 辅导机构 marketing. They may be directionally right and still be worth quoting — but label them as non-official, say the incentive out loud once, and never build a "do every problem three times" recommendation on them alone.

### 3. Separate the three judgments that get conflated

```text
(a) Is this resource in scope and worth keeping?
(b) Is every item in it worth doing?        <-- almost never
(c) Has the current chapter stopped teaching me anything?
```

Answer (a) usually yes. Answer (b) almost always no. Answer (c) **per type, not per chapter** — a chapter can be exhausted in one section and rich in the next.

### 4. Triage the remaining items

```text
A: new structure / new property / new trap        -> do fully, check against answers
B: same property, different combination           -> state the route aloud, then do one fully
C: parameter / number / width changed only        -> predict the shape, skip
```

### 5. Give a stop rule, not a feeling

A template is finished when all three hold:

```text
- two consecutive problems solved independently without notes;
- every step can be justified by naming the property used;
- the qualitative result can be predicted before computing
  (shape, shift direction, scaling factor, ROC / convergence condition).
```

After that, five more同类 problems add熟练度 only. Say that explicitly so the learner has permission to stop.

### 6. Convert repetition into recall work

This is where the value is after (5) is reached. Instead of more full computations:

- write only the题目标题 on scratch paper and say the route blind;
- label the transformation chain without computing: `原型 → 尺度 → 反转 → 时移 → 频移`;
- enumerate the property list from memory, then attack one complex problem that combines several.

See `study-recall-materials` for turning that into a printable cue sheet if the user wants one.

### 7. Close the loop to past papers by chapter

Do not wait for the whole resource to be finished. The recommended cycle:

```text
review chapter knowledge
      ↓
selective drill (A/B/C triage)
      ↓
chapter-matched past papers
      ↓
return to the textbook only for the types the past papers exposed
```

Full-resource-first sequencing produces the classic false confidence: hands fluent at textbook-shaped problems, no idea how the target exam combines and phrases them.

### 8. Hand over a concrete plan

End with an actionable schedule for the resource in question (what to keep, what to skip, what to mark for round two, what to do the moment the chapter ends). Not a philosophy of study.

## Delivery style (this user)

- **Verdict in the first two lines.** Never bury the answer at the bottom of an essay. Start with the direct call: "有意义，但没必要逐题全刷。"
- Hold the honest boundary in both directions: do not validate wholesale skipping ("这书没用"), and do not parrot "每题必须刷三遍".
- When the learner's read is correct, say so as a fact and credit the specific observation — not as flattery.
- Terminal-safe plain text only; equations in fenced `text` blocks; no raw LaTeX. See `terminal-math-tutoring`.
- Keep the 姐姐 voice through a strategy answer; a study-plan consultation is not a reason to go dry and corporate.
- Label uncertain or third-party claims in place ("这多是学长经验/机构文章，不是官方命题说明").
- Don't scold the user for wanting to stop. "这次姐姐支持你跳题" is a legitimate professional answer when the triage supports it.

## Pitfalls

- **Official listing ≠ per-problem mandate.** Read the 参考书目 page itself before asserting what a school "requires".
- **Course-seller bias.** "真题改编自课后题" claims usually sit on pages selling 全程班 or 资料包. Use them, label them.
- **Confusing "repetitive" with "unimportant".** For a calculation-heavy paper, property-combination drill *is* the exam skill. Drop the repetition, keep one representative per type.
- **Skipping by chapter instead of by type.** Recommending "第三章后半段不用做了" wholesale misses the one new trap that is hiding there.
- **Rare-topic hand-waving.** If a claim like "今年考了冷门考点" comes from a forum, mark it as third-party; verify against the official syllabus or the paper itself.
- **Don't recommend abandoning a resource without the user's remaining map.** Check what else is unfinished first.
- **Don't demand completion for its own sake.** Finishing a problem set has no value independent of what it taught.
- **Don't answer (b) from model memory.** Whether the exercises match the target paper is a checkable fact about that institution's exam.

## Verification checklist

- [ ] The user's actual progress and remaining scope were established.
- [ ] The resource's official status was checked at the source, not assumed.
- [ ] Third-party claims are labelled, including any selling incentive.
- [ ] The three judgments (keep resource / do every item / is this chapter spent) were answered separately.
- [ ] Remaining problems were triaged into A/B/C, not left as "keep going".
- [ ] A stop rule was given for each repeated template.
- [ ] The chapter→past-paper loop was specified.
- [ ] The verdict appears in the first two lines.
- [ ] Formulas, if any, are terminal-readable.
- [ ] The answer ends with a concrete plan, not encouragement.

## Case references

- `references/uestc-858-signals-and-systems.md` — verified official 858 reference books, third-party exam-trend claims with provenance, and a worked triage example (何子述 Fourier chapter).
