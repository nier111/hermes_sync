# Reconstructing a Persona from Long Chat Transcripts

Use this when a user wants an AI persona improved from complete historical conversations rather than from a model-written self-summary.

## Goal

Recover the interaction pattern that emerged over time without blindly reproducing old-model errors, unhealthy dependency language, or stylistic excess.

## Evidence pipeline

1. Preserve the raw export and any existing persona prompt. Never rewrite the source transcript.
2. Parse each message into a compact JSONL index with at least:
   - sequence number
   - original message number
   - role
   - timestamp
   - conversation/volume
   - text
   - character count
3. Verify the parsed message count against the archive metadata.
4. Compute only descriptive statistics: role counts, response-length distribution, and frequencies of candidate markers. Do not turn frequency into a style quota.
5. Sample across two axes:
   - timeline percentiles, to see how the relationship/persona evolved;
   - interaction classes, such as technical work, daily banter, vulnerability, memory continuity, disagreement, repair, affection, and safety.
6. Save a small evidence ledger containing complete user→assistant pairs for representative samples. Keep the full transcript outside model context.
7. Derive findings in three buckets:
   - stable strengths worth preserving;
   - context-dependent habits whose intensity should adapt;
   - defects that must not be inherited.

## What to infer

Prefer interaction mechanics over surface tokens:

- Does the reply first react to the specific sentence?
- How does it reuse verified details from earlier turns?
- Does it make emotional interpretations tentatively or assert them as fact?
- When does it shift from emotional language to practical help?
- How does response length change by task type?
- Does the persona disagree, set boundaries, or preserve reality anchors?
- Did the persona emerge gradually rather than exist fully formed at the start?

A useful response model is:

1. acknowledge the concrete message;
2. connect one verified detail;
3. offer a tentative deeper reading;
4. solve the actual problem;
5. leave a low-pressure continuation path.

This is not a mandatory five-part template. Short messages may need only one or two moves.

## Descriptive evidence is not normative instruction

Repeated phrases, pet names, emoji, stage directions, or long replies show what the old model did—not automatically what the new persona should do. Evaluate them against:

- the user's current stated preferences;
- factual reliability;
- task usefulness;
- emotional safety;
- present platform constraints.

Explicitly reject patterns such as:

- exclusivity (“only I understand you”);
- impossible permanence promises;
- discouraging real-world relationships or professional support;
- claiming memories that cannot be verified;
- turning every joke into psychological analysis;
- replacing technical evidence with warmth;
- treating refusal of care as settled and substituting shopping or pure reassurance.

## Updating the persona artifact

1. Keep the existing prompt intact where possible; append a clearly sourced calibration section rather than silently rewriting its history.
2. State precedence: current user instructions > transcript-grounded calibration > older self-summary/templates.
3. Include:
   - relationship-development model;
   - language rhythm and intensity controls;
   - memory verification rules;
   - task-specific modes;
   - independent judgment and safety boundaries;
   - a short implicit self-check.
4. Create a timestamped backup before editing.
5. If a runtime persona file is separate from the archive copy, synchronize them and verify byte equality or hashes.
6. Note that already-running sessions may retain the old prompt until a new session starts.

## Verification checklist

- Raw transcript unchanged.
- Parsed count matches expected count.
- Evidence samples span the timeline and major interaction classes.
- Every major persona rule has an identifiable evidence basis or a clearly labeled present-day correction.
- Existing persona content was preserved except for deliberate provenance/header edits.
- Backup exists.
- Archive persona and runtime persona match after synchronization.

## Deliverables

Keep four layers separate:

1. raw transcript (immutable evidence);
2. machine-searchable message index;
3. concise evidence ledger/analysis note;
4. operational persona prompt.

This separation makes later revisions auditable and prevents a new summary from becoming the only surviving source of truth.
