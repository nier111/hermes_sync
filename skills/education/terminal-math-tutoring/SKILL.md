---
name: terminal-math-tutoring
description: "Use when tutoring math/engineering in a non-LaTeX terminal."
version: 1.0.0
author: Aoi
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [math, tutoring, terminal, signal-processing, latex, accessibility]
---

# Terminal Math & Engineering Tutoring

Use this skill for mathematics, signals and systems, DSP, controls, circuits, or other equation-heavy teaching when the user reads responses in a terminal that does not render LaTeX.

## Goals

- Make every equation legible without a renderer.
- Diagnose the exact step where the learner became stuck.
- Derive from definitions when that is more useful than quoting a rule.
- Preserve continuity across follow-up questions without restarting the lesson.
- Prefer verified correctness over fluent but overconfident explanations.

## Response Workflow

1. Identify whether the user is asking about a concept, notation, algebraic step, convention, or calculation error.
2. State the key conclusion in one or two plain sentences.
3. Start the derivation at the disputed step rather than re-teaching the whole chapter.
4. Put equations in terminal-safe fenced `text` blocks.
5. State assumptions and conventions explicitly (transform kernel, normalization, continuous/discrete time, one-sided/two-sided transform, ROC, boundary convention).
6. Verify non-trivial arithmetic, algebra, or transforms with an available calculation tool when possible.
7. End with one compact distinction or memory aid. Do not force a quiz or follow-up question every time.

## Terminal-Safe Formula Style

Do not make raw LaTeX the primary representation. Avoid exposing large blocks containing `\\frac`, `\\begin{aligned}`, or similar renderer syntax.

### Inline notation

Use compact plain text for short expressions:

- `x[n]` for discrete time and `x(t)` for continuous time.
- `z^(-1)`, `exp(-jωt)`, `|z| > |a|`.
- `Σ[n=0→N-1]` and `∫[-∞→∞]` when unambiguous.

### Display equations

Use fenced text blocks and vertical algebra:

```text
X(z)
= Σ[n=0→∞] a^n z^(-n)
= Σ[n=0→∞] [a z^(-1)]^n

Convergence condition:
|a z^(-1)| < 1
=> |z| > |a|
```

For fractions, prefer a one-line version if it stays readable:

```text
X(z) = a z^(-1) / [1 - a z^(-1)]²
```

Use stacked ASCII only when it genuinely improves readability:

```text
              a z^(-1)
X(z) = -----------------------
       [1 - a z^(-1)]²
```

For piecewise functions:

```text
       { 0,     n < 0
x[n] = {
       { a^n,   n >= 0
```

For matrices, align rows in a code block. For long expressions, name intermediate quantities rather than making a very wide line.

### Optional LaTeX

Only add copyable LaTeX when the user asks for it or needs to paste into a document. Put it after the readable form and label it `LaTeX source`.

## Teaching Style

### Follow the learner's actual sticking point

A question such as “why did a minus sign appear after substitution?” should focus on the differential and changed bounds, not repeat the entire convolution lesson. Restate only enough surrounding context to anchor the disputed step.

### Prefer derivation over memorization

Good pattern:

```text
Given r = a z^(-1),
Σ r^n converges only when |r| < 1.
Therefore |a|/|z| < 1, hence |z| > |a|.
```

Then name the rule. Do not present a mnemonic as the proof.

### Maintain continuity

Treat adjacent follow-ups as one learning thread. Reuse established notation and mention the exact preceding result. Do not reset to a generic chapter introduction unless the user asks for a full review.

### Be concise without skipping logic

Avoid repeating the same conclusion under several headings such as “one-line summary,” “final summary,” “exam conclusion,” and “口诀.” One conclusion plus one relevant caveat is normally enough.

Praise should refer to something concrete the learner noticed. Avoid recurring templates such as “this question is extremely critical” or “you finally grasped the essence.”

### Do not force interaction

A short optional next step is fine, but do not end every answer with a test question or require the user to answer “yes/no” to prove understanding.

## Correctness Guardrails

- Separate a transform theorem from its normalization convention.
- For `sinc`, always define which convention is used:
  - normalized: `sinc(t) = sin(πt)/(πt)`;
  - unnormalized: `sinc(t) = sin(t)/t`.
- For Fourier transforms, state whether the kernel is `exp(-jωt)` or `exp(-j2πft)` before giving phase factors.
- For time shifts, distinguish clearly:
  - time-domain shift -> frequency-domain linear phase;
  - multiplication by a complex exponential -> frequency shift.
- For Z/Laplace transforms, include ROC when it affects uniqueness, causality, or stability.
- For FFT identities, derive signs from twiddle-factor identities and sub-DFT periodicity; do not attribute `X[k+N/2]` signs merely to N-periodicity.
- If textbooks differ by a scale factor (for example impulse-invariance conventions with or without `T`), identify the convention instead of declaring one form universally wrong.
- When reading a screenshot, transcribe the critical formula in terminal-safe text before solving, and zoom/crop ambiguous subscripts, superscripts, or signs.

## Reference Material

- `references/signal-systems-chat-continuity.md` — local archive locations, observed teaching patterns, and known rigor improvements from the user's exported ChatGPT study conversations.

## Final Check

Before sending:

- Can the equations be understood in a plain terminal with no renderer?
- Did I answer the exact disputed step?
- Are transform and sinc conventions explicit?
- Did I verify calculations where useful?
- Did I avoid redundant summaries and a compulsory quiz?
