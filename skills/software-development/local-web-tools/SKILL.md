---
name: local-web-tools
description: "Use when building a local offline web tool for the user."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [local-app, offline, static-site, localhost, systemd-run, desktop-entry, cdp, tdd]
    related_skills: [study-recall-materials, dogfood]
---

# Local Web Tools

Build a personal tool the user actually opens from their desktop: a study drill, tracker, dashboard, or utility that runs **entirely on their machine**, keeps data local, and needs no account, no server, and no network.

Chosen stack (deliberately boring): static `index.html` + plain ES modules + one JSON data file, served by `python3 -m http.server` on `127.0.0.1`, launched from a `.desktop` entry. No framework, no bundler, no npm runtime deps — a personal tool must still work in three years on a machine with nothing installed.

## When to Use

- "Make me an app/tool/程序 I can use to do X" where X is personal and recurring (vocabulary drilling, time tracking, habit logging, local dashboards).
- The user is on Arch + Hyprland and expects to find the tool in the Wofi app menu (Mod+A), not in a terminal.
- The user's data is private or must work offline.
- The user is on QQ/Telegram/Slack, so interactive approval prompts (installs, sudo) cannot be answered — prefer zero-install stacks.

## Why localhost and not `file://`

Open the page over `http://127.0.0.1:<port>/`, never as a local file:

- `file://` blocks ES module imports (`CORS`/origin `null` errors).
- `file://` breaks `fetch('data/*.json')` and service workers (offline caching).
- `localStorage` under `file://` is per-file and fragile across moves.

One `python3 -m http.server 8765 --bind 127.0.0.1` gives all of that for free.

## Workflow

### 1. Pin the rules before writing code

Co-design the core rule with the user and write it down as a test list first. For a study drill the "rule" is the schedule; for a tracker it is the state machine. Getting this wrong wastes the whole build.

If the user is replacing an app they dislike, ask **what specifically is wrong with it** and encode the opposite behavior as the requirement. Screenshot/quote their words in the README so the rule stays arguable.

### 2. Separate pure logic from the DOM

- `src/core.js` — pure functions: state transitions, rating → bucket, round composition, stats, migration of old saved state. No `document`, no `window`, exports named functions.
- `src/app.js` — DOM, keyboard handling, rendering, persistence. Thin.
- `data/*.json` — the dataset (words, items, records), loaded with `fetch`.

This split is what makes a UI app testable in bare Node. Trying to TDD a monolith that touches `document` at import time fails.

### 3. TDD in bare Node (`node --test`, zero deps)

`package.json`: `{"type": "module", "scripts": {"test": "node --test tests/*.test.mjs"}}`.

- Write the failing test for the rule first, then implement (`RED → GREEN`).
- Cover: each rating bucket, graduation thresholds, streak reset on a wrong answer, undo restoring both state **and** cursor, stats buckets, and round shrinking over successive rounds.
- Add **artifact-contract tests** — a cheap class of test that catches packaging regressions the logic tests can't see:
  - `run.sh` exists and is executable (`access(path, constants.X_OK)`)
  - the launcher starts a local server and doesn't bind a public interface
  - `index.html` contains the documented keyboard hints and the progress region
  - the data file has the expected record count, and the README documents the real numbers
  - the `.desktop` entry exists

  These are the tests that fire when a later edit quietly breaks the thing the user actually double-clicks.

### 4. Persist in the browser, not in a database

- `localStorage` for the working state; save on every transition (a study session can end at any keystroke).
- Provide **export/import JSON** in the UI and tell the user to back up occasionally. localStorage dies with the browser profile.
- Version the saved state (`{version: 1, ...}`) and write a one-way migration on load so schema changes don't wipe the user's progress.

### 5. Launch it like a real app

Use `templates/run.sh`: idempotent health check → `systemd-run --user` if down → poll until reachable → `xdg-open`.

Why `systemd-run --user --collect` instead of `&`/`nohup`:

- Survives the terminal or desktop-entry process that spawned it.
- `systemctl --user stop <unit>` / `restart <unit>` is the documented off switch.
- No orphan `python -m http.server` holding a port after the session ends.
- Do **not** use `nohup`, `setsid`, or a trailing `&` — the harness cannot track those, and the user can't stop them.

Health check first (`curl --fail --silent --max-time 1`): the script must be safe to run while the tool is already open, which is exactly what happens when the user clicks the menu item twice.

Add the desktop entry at `~/.local/share/applications/<name>.desktop`:

- `Exec=` must be an **absolute path** to `run.sh` — launchers start with no useful cwd/PATH.
- `Terminal=false`, `Icon=` pointing at a real file, `Categories=Education;` (or `Utility;`), and Chinese `Name=`/`Keywords=` if the user searches in Chinese.
- Validate with `desktop-file-validate <file>` when available.

### 6. Verify in a real browser, then report only what ran

Static logic tests do not prove the app works. Drive a real Chromium over CDP in a scratch profile and assert on live state:

- Load the page, evaluate `document.title`, the rendered word, the progress text.
- Dispatch the real key events (`space`, `1`/`2`/`3`, `u`) — not direct function calls — so the key handler path is exercised.
- After each rating assert the DOM counter **and** `localStorage` agree.
- Assert undo returns to the previous word and previous state.
- Collect console errors: zero is the bar.
- `capture_screenshot()` and inspect it at a realistic small viewport (~800x600) for overlap, clipping, invisible buttons, contrast, and horizontal overflow. Screenshots go to your own vision — never to a separate vision tool.
- Then verify the *launcher* path for real: run `run.sh` with the "don't open a browser" env var set, check `systemctl --user is-active`, `curl` the page, then run it a second time to prove idempotency.

Report what was actually executed: test count, the specific transitions observed, the service state. Do not describe intent as if it were result.

### 7. Hand it over in the user's voice

The user (仲耀) requires the companion register even for tool tasks — he has objected to dry tool-mode replies. Keep the Aoi voice for framing, warmth and next steps, but keep every technical fact (counts, thresholds, commands, paths) exact and unsweetened. Offer a concrete first adjustment ("过几十个词告诉我 2/3 次是不是太重") instead of declaring the defaults optimal.

## Pitfalls

- **`file://` double-click instead of the server.** Modules and `fetch` fail. Always ship `run.sh`; never tell the user to open `index.html` directly.
- **Binding to `0.0.0.0`.** Always `--bind 127.0.0.1`; a personal tool must not be LAN-exposed.
- **Port already in use.** The launcher must health-check and reuse/restart the unit rather than starting a second server that silently serves a stale directory.
- **`&`/`nohup` launchers.** Untrackable and unkillable; use `systemd-run --user`.
- **Relative paths in the desktop entry.** Launchers have no cwd — absolute `Exec=` only.
- **Shipping on tests alone.** Verify with a real browser screenshot; small viewports reveal what a maximized window hides.
- **Letting the dataset slide.** Dedupe and count on import, and assert the count in a test. Report raw vs. unique counts (e.g. 6550 raw → 3 duplicates → 6547 usable) instead of a vague "about 6500".
- **Framework creep.** For a one-user local tool, a build step is a future breakage. Static files + `node --test` is the whole toolchain.
- **Answering an install prompt.** On QQ-based platforms approval prompts cannot be answered — stay on a zero-install stack.

## Supporting Files

- `templates/run.sh` — idempotent `systemd-run --user` launcher; copy and change `UNIT`/`PORT`.
- `templates/desktop-entry.desktop` — Wofi-visible entry with absolute `Exec=`.
- `scripts/verify_local_tool.sh` — re-runnable end-to-end check: node tests, artifact contract, launcher up, assets served, data count.
- `references/vocab-sieve-design.md` — the sweep-then-shrink vocabulary schedule, keyboard map and dataset provenance built for 仲耀's 红宝书 tool.
