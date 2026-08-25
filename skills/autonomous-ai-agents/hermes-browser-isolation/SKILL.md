---
name: hermes-browser-isolation
description: "Use when Hermes browser automation disrupts desktop."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, browser-use, chromium, cron, hyprland, isolation]
---

# Hermes Browser Isolation on Linux

Use this skill when `browser_exec`, browser-use, or an agent-mode cron opens tabs/windows in the user's everyday browser, steals workspace space, or repeatedly leaves blank Chromium windows.

## Core rule: isolate capability; do not remove it

When the user still wants browser-backed search, **do not solve desktop interference by permanently removing the `browser` toolset**. Preserve the capability and isolate it:

1. Dedicated Chromium process
2. Dedicated `--user-data-dir` (separate cookies/session state)
3. Loopback-only CDP port
4. Distinct window class/app ID
5. Window-manager rule sending it to a quiet workspace
6. Stable named `browser_exec` session per recurring job

Disabling browser access is appropriate only when the user explicitly prefers search-only/curl operation or the task does not need rendering.

## Diagnose before changing anything

Establish who opened the windows rather than guessing:

1. Record current time.
2. Inspect compositor windows (`hyprctl clients -j` on Hyprland): title, class, PID, workspace.
3. Inspect browser process start times and parent processes.
4. List cron jobs and compare `last_run_at` with the appearance time.
5. Search Hermes logs for `tool browser_exec completed` under the matching cron session.
6. Inspect browser history only as secondary evidence; internal pages such as `chrome://inspect` may not appear there.

A recurring cron can be the cause even if no browser-use daemon remains after completion: the daemon exits while the Chromium windows survive.

## Why named sessions alone are insufficient locally

`browser_exec(session="name")` isolates the harness daemon and tab ownership. On a shared local-Chrome backend it can still attach to the user's existing browser process. A named session is therefore useful for concurrency, but it is **not** process/profile/workspace isolation.

For real desktop isolation, point Hermes at a dedicated CDP endpoint using:

```bash
hermes config set browser.cdp_url http://127.0.0.1:9222
```

Never hand-edit `config.yaml`; use `hermes config set`.

## Reference architecture

Launch a separate Chromium instance with:

```text
--user-data-dir=$HOME/.hermes/browser-profiles/automation
--remote-debugging-address=127.0.0.1
--remote-debugging-port=9222
--class=hermes-browser
--no-first-run
--no-default-browser-check
```

Run it as a user service so cron can rely on the endpoint. Bind CDP to `127.0.0.1`, never `0.0.0.0`, because CDP grants full control of that browser profile.

On Hyprland, match the dedicated class—not generic `chromium`—and send it silently to a reserved workspace. A generic Chromium rule would also relocate the user's own future windows.

The validated unit, Hyprland rule, cron prompt, and commands are in `references/hyprland-dedicated-browser.md`.

## Cron configuration

For a recurring research job:

- Include `browser` alongside `web`, `terminal`, and `file` toolsets.
- Tell the agent to prefer `web_search`/`web_extract`/curl and use `browser_exec` only for rendered or blocked pages.
- Require one stable session name, e.g. `session="daily-research"`.
- Explicitly prohibit `computer_use` and interaction with the user's everyday Chromium.

This reduces unnecessary GUI work while preserving the fallback that motivated browser access.

## Verification gate

Do not report success until all checks pass:

1. `curl http://127.0.0.1:9222/json/version` returns a DevTools endpoint.
2. `hyprctl clients -j` shows class `hermes-browser` on the reserved workspace.
3. A real `browser_exec` call with the cron's named session navigates to a test page and reads its title/URL.
4. Re-check compositor windows: the user's active workspace and everyday Chromium have no new windows; only the dedicated browser changed.
5. Confirm the cron still has the `browser` toolset and its prompt names the isolated session.

## Pitfalls

- **Do not infer from window titles alone.** Correlate PID/workspace timestamps with Hermes cron logs.
- **Do not rely on a prompt saying “open on workspace N.”** The browser driver does not control compositor placement; enforce it with a window rule.
- **Do not match all Chromium windows.** Give the automation browser a unique class.
- **Do not share the user's profile directory.** Chromium may reuse the existing process, and automation gains access to personal cookies/tabs.
- **Do not stop after writing config.** Launch the service, exercise `browser_exec`, and inspect the resulting workspace.
- **Do not encode temporary failures as permanent limitations.** Capture the working isolation architecture, not transient setup errors.

## Related skills

- `hermes-agent`: authoritative Hermes browser/config/cron documentation (protected/bundled).
- `hermes-desktop-linux`: Electron desktop build and launcher issues; some Linux/Hyprland overlap, but browser-runtime isolation belongs here.
- `cron-reminders`: cron scheduling/output diagnosis; use this skill when the cron's browser side effects are the problem.
