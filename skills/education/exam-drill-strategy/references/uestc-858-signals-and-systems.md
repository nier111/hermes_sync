# UESTC 858 信号与系统 — reference books and drill triage

Session-derived case study (September 2026, user preparing for UESTC 电子信息硕士, paper 858). Treat institutional specifics as verified-at-that-date, not permanent.

## Official reference books (verified)

From the official UESTC graduate-admissions reference-book page, which is plain rendered HTML and is the correct source for this question:

```text
https://yz.uestc.edu.cn/info/1052/3672.htm
(2026年全国硕士研究招生考试电子科技大学初试自命题科目参考书目, 发布 2025-09-30)
```

Subject 858 信号与系统 officially lists **three** books:

```text
SIGNALS and SYSTEMS          A.V. Oppenheim   电子工业出版社
《信号与系统》               何子述           高等教育出版社
《信号与系统》               杨建宇           高等教育出版社
```

Consequences:

- 何子述 is genuinely official, so "停止做何子述" would be wrong advice.
- Listing three books means the school describes a knowledge system. It is **not** a mandate to finish every exercise of all three. Quote this distinction when the user asks what the school "requires".

### Attachment mechanics

The 自命题科目考试大纲 PDF on the sibling announcement sits behind:

```text
/system/_content/download.jsp?urltype=news.DownloadAttachUrl&owner=...&wbfileid=...
```

Raw `curl` on that handler returns a small HTML browser-check page, which then fails `pdftotext` with "Could not find trailer dictionary". Verify any download with `file` before parsing. For the "which books / what scope" question, the 参考书目 page alone is sufficient and avoids the handler entirely. See also `graduate-admissions-research/references/uestc-2026-to-2027.md` for the full browser-mediated attachment procedure.

## Third-party evaluation consensus (secondary — label it)

Sources are 知乎 经验帖 and 考研 institutions' pages, which sell 全程班 / 资料包. Directionally useful, not 官方命题说明.

```text
+ 何子述 is a 信通院 professor's book; thinner than Oppenheim; style closer to 858.
+ 课后题与例题与真题相关，被反复提到会"改编"进真题。
+ Some proofs are regarded as neater than Oppenheim's (e.g. 单边拉氏微分).
- 题目数量多、重复度不低，"需要有选择性地刷题"。
- 何版课后题只有答案、无解析 → 通常需要额外详解资料或 B 站带学视频。
- 奥本海姆内容更全（如希尔伯特变换之外的部分），两本结合是常见建议。
```

Do not convert the "改编自课后题" claim into "每道课后题都要做". It comes from pages selling courses.

## Third-party exam-trend claims (secondary)

```text
- 常考结构：基本概念与性质 / LTI / 连续时间傅里叶 / 拉普拉斯 / Z 变换，
  每部分约 1–2 道大题。
- 2024: 考到较冷门的带通采样定理（同一时期帖子里被反复提及）。
- 2025: 首次考察离散时间傅里叶变换，首次难度不高，但可能之后上难度。
- 从 2025 起改卷无步骤分 →答案错即全错，解题步骤、收敛域、答案形式开始影响得分。
- 22 年难度很高，23 年明显回落，难度有波动。
- 希尔伯特变换：何子述有、奥本海姆正文无，属于何版独有考点。
```

Treat 2024/2025 paper-difficulty recollections as forum claims. If it matters, verify against the actual paper.

## Worked triage example: 何子述 第三章（傅里叶变换）

User's position: 第三章 halfway done; observation "复习完知识点之后完全就是傅里叶变换性质的反复运用".

Verdict given:

```text
继续做有意义，但"从头到尾逐题全刷"已经不太有意义。
把它从"必须清空的任务清单"改成"按题型抽取的题库"。
```

Reasoning:

- The observation is correct, and it is evidence of emerging pattern recognition — say so as fact, not flattery.
- Repetition of property combinations is still the actual 858 skill: recognise the structure quickly, pick the right property chain, control scaling / sign / phase / impulse coefficients. It is not deep, but the paper rewards it.
- Therefore: keep one representative per property and per combined structure; stop the parameter-only repeats.

Triage applied to the remaining chapter problems:

```text
A (do fully, check answers)
  - 看不出从哪个基本变换对出发
  - 两条以上性质组合、顺序容易乱
  - 含时移 / 尺度 / 反转，容易错相位或漏绝对值
  - 含冲激、阶跃、符号函数等广义函数
  - 由频谱反推时域
  - 与系统频响、采样、调制、希尔伯特变换结合
  - 形式熟悉但结果总与答案不同

B (state the route aloud, then do one fully)
  - 性质相同、组合方式略有变化

C (predict the shape, skip)
  - 只有参数、数字或波形宽度变化
```

Stop rule given: two consecutive problems solved with no notes + every step justifiable by naming the property + qualitative result predictable before computing.

Recall substitute: write only the题目标题, then blind-label the chain `原型 → 尺度 → 反转 → 时移 → 频移`, and recite the property list from memory.

Chapter close: immediately do chapter-matched 858 真题, then return to 何子述 only for the exposed types. Explicitly avoid the sequence "何子述全刷 → 奥本全刷 → 习题集全刷 → 最后才碰真题".

## Durable insight from this case

The chapters that feel repetitive (long transform-property chapters) are **not** where 858 has surprised candidates. The surprise lived in short application chapters — 采样/带通采样, 希尔伯特变换, and the newly introduced DTFT. So "this chapter is boring and repetitive" is a reason to triage that chapter, not a reason to relax on the short application chapters.

## Local context

- User's study log and materials: `~/Documents/考研/` (includes `study-log.md` daily check-in).
- 858 subject scope and 学院-level score analysis also exist in the user's OpenClaw knowledge base.
