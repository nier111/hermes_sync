---
name: coursework-essay-writing
description: "Use when drafting or revising university coursework essays."
version: 1.0.0
metadata:
  hermes:
    category: writing
    tags: [coursework, essays, academic-writing, citations, humanization]
---

# Coursework Essay Writing

Use this skill for university course papers, reflection essays, policy essays, and other assessed prose where the user provides a prompt, minimum length, or marking criteria. The goal is a submission-ready draft grounded in real sources, tailored to the student's field, and easy for the student to review and revise.

## Core principles

- Treat the marking prompt as a specification. Every requested theme, length rule, and structural requirement must appear in the artifact.
- Write an actual paper, not an outline or a promise to write later.
- Prefer specific claims and concrete examples over slogan stacking or generic praise.
- Never invent the student's experiences, course content, survey results, quotations, or citations.
- Personalize only from known facts. If the user's major, projects, or interests are known, connect them naturally to the topic without exposing unrelated private details.
- The student remains responsible for reviewing the argument, adapting it to the instructor's expectations, and submitting it.

## Workflow

### 1. Parse the assignment

Extract:

- Allowed or required themes
- Minimum or maximum length
- Required components such as title, abstract, keywords, references, or cover information
- Expected stance and analytical method
- Whether the task asks for reflection, argument, research, or practical proposals

If the prompt offers several themes and no choice is requested, select one that can integrate the greatest number of requirements. Do not ask for clarification when a sensible default exists.

### 2. Choose a defensible thesis

Form one sentence that the entire paper will prove. A strong thesis links:

- The historical or theoretical frame
- A current issue or concrete social problem
- The student's own discipline or practical responsibility

Avoid titles that merely restate the course name. Prefer a title that identifies both the lens and the claim.

### 3. Ground current and quoted claims

For political, policy, economic, historical, or statistical claims:

1. Retrieve primary or authoritative sources first: official reports, laws, white papers, statistical releases, or original speeches.
2. Register sources while retrieving them when the grounded-citations skill is available.
3. Cite exact figures and dated claims inline.
4. End with a mechanically checked reference list.
5. Do not cite search snippets as though the full source was read.

Three strong primary sources are usually better than ten low-quality commentary pages. Use secondary scholarship when the assignment genuinely requires literature review.

### 4. Build an argument rather than a list

A reliable structure is:

1. Introduction: course context, problem, thesis
2. Historical or theoretical foundation
3. Analysis of the current situation using the requested method
4. Tensions, limitations, or countervailing facts
5. Concrete student actions linked to the analysis
6. Conclusion that answers the thesis without generic optimism

Each section should advance the central claim. Transitions should arise from the logic of the argument, not from repetitive signposts such as “firstly, secondly, finally.”

### 5. Personalize carefully

Use known, relevant details to make the paper plausible and specific. For an engineering student, practical measures may include testing discipline, safety, documentation, reproducibility, technical foundations, and solving real user needs. For another discipline, substitute appropriate professional responsibilities.

Do not fabricate participation in events, internships, volunteer work, experiments, or classroom discussions. Phrase proposed actions as commitments or future practice unless the experience is known to be real.

### 6. Run an anti-template pass

Before delivery, remove common AI-writing tells:

- Empty significance claims and inflated language
- Repeated three-part lists
- Vague authorities such as “experts believe”
- Excessive “not only...but also...” constructions
- Uniform paragraph length and mechanical transitions
- Generic conclusions such as “the future is bright”
- Chatbot artifacts such as “I hope this helps” inside the paper

Preserve an academic tone, but allow varied sentence rhythm and qualified judgment. In political coursework, a clear stance does not require suppressing real tensions; acknowledging difficulties often makes the argument more rigorous.

### 7. Verify the artifact

Before reporting completion:

- Count the body length with a tool. For Chinese assignments, report Chinese-character count separately from total characters when possible.
- Confirm every inline citation maps to a real reference.
- Check that all prompt requirements are visibly covered.
- Ensure the final file uses the expected Chinese heading “参考文献,” even if citation tooling temporarily uses “Sources” during verification.
- Confirm the file was actually written and provide its absolute path.

## Delivery format

State:

- Paper title
- Absolute file path
- Verified body length
- Source count or citation status
- What was personalized
- Any fields the user still needs to add, such as name, student number, college, instructor, or date

Do not bury the artifact under a long explanation.

## Submission and locked editors

If the user asks for help entering the paper into a web form:

- Inspect the actual page and editor implementation before suggesting a workaround.
- Stop at login walls and let the user authenticate.
- Do not claim a paste restriction has been bypassed until text entry is tested successfully.
- Fill content only after the user is logged in, and leave the final submit action to the user unless they explicitly request submission and the consequences are clear.
- Do not preserve unverified bypass attempts as procedure.

## Supporting references

- See `references/chinese-policy-course-papers.md` for a compact checklist and source hierarchy for Chinese “形势与政策” style papers.

## Pitfalls

- Meeting “2000 words” by counting all Markdown syntax, URLs, and references instead of the body
- Writing a neutral encyclopedia entry when the rubric asks for a clear position
- Filling the paper with policy quotations but providing no analysis
- Adding personal details that are true but irrelevant or too private
- Treating slogans as evidence
- Reporting completion before checking length and citations
- Giving generic browser-console bypass instructions without inspecting the page

## Verification checklist

- [ ] Thesis is explicit and defended throughout
- [ ] Every required theme is addressed
- [ ] Current facts come from retrieved authoritative sources
- [ ] References and inline numbers agree
- [ ] Body exceeds the minimum length with a safe margin
- [ ] Personal examples are relevant and not fabricated
- [ ] Final prose has passed an anti-template review
- [ ] Artifact exists at the reported path
