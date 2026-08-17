# Memory architecture & input-cost facts (verified 2026-08)

## Memory is markdown files; limits are configurable
- `~/.hermes/memories/MEMORY.md` (agent's long-term memory) and `USER.md` (user
  profile) — the `memory` tool edits these directly. Entries are `§`-separated.
- Char budgets are per-turn injection limits, NOT disk limits:
  `hermes config set memory.memory_char_limit 5000` (default 2200) and
  `memory.user_char_limit 3000` (default 1375). Raised on this box to stop constant
  compaction. Use `hermes config set`, never hand-edit config.yaml.
- Layered design (this is why detail lives in files, not memory): MEMORY/USER =
  always-injected index (core methodology, key paths, persona pointers); heavy detail
  in `~/persona/*.md`, the user's Obsidian knowledge base
  (`~/projects/HelpListCreatedByAyane`), and skill references loaded on demand.
  Everything injected every turn costs tokens and dilutes attention.

## Why input tokens ≫ output tokens (and how to cut spend)
- Every request re-sends: system prompt + memory + user profile + full skills index +
  tool schemas + entire history. Output is only the reply. 100:1–300:1 ratios are
  normal, not a leak.
- Hermes has built-in session compression (compression.enabled=true, threshold 0.5 →
  compress to target_ratio 0.2, protect_last_n 20). Long single sessions are the main
  input-growth driver — rotate sessions (agent-pool handoff pattern) rather than
  letting one session span days.
- cron/delegation can restrict toolsets (enabled_toolsets) to shrink tool-schema
  overhead per run.

## Headroom (context compression tool) status
- Headroom's compatibility table covers OpenClaw ContextEngine + Codex wrapper, NOT
  Hermes. Hermes has its own session-level compression; a GitHub issue tracks Headroom
  integration. Decision (2026-08): don't bolt Headroom onto Hermes — use built-in
  compression + memory layering + session rotation.

## Memory capture discipline (user expectation)
- The user expects ACTIVE capture: preferences, experiences, in-progress state (what
  book they're reading, new gear, environment fixes) should be saved as they surface,
  not only when the user says "记住:". High-signal → save immediately; one-off task
  detail → leave in session history (session_search can find it).
- If a fix/decision is made (e.g. QQ font rendering), record the fix location +
  parameters in memory/skill so a reinstall/update can restore it.
