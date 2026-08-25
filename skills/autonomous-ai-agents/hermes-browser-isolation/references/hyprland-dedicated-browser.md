# Hyprland dedicated browser: validated reference

This recipe keeps Hermes/browser-use visible but off the user's active workspace. It was validated with Chromium on Wayland + Hyprland.

## 1. User service

Path: `~/.config/systemd/user/hermes-browser.service`

```ini
[Unit]
Description=Dedicated Chromium for Hermes browser automation
After=graphical-session-pre.target

[Service]
Type=simple
ExecStart=/usr/bin/chromium --user-data-dir=%h/.hermes/browser-profiles/automation --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --class=hermes-browser --ozone-platform=wayland --no-first-run --no-default-browser-check --disable-session-crashed-bubble --proxy-server=socks5://127.0.0.1:7891 about:blank
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

Adapt/remove the proxy flag for other hosts. Then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-browser.service
curl -fsS http://127.0.0.1:9222/json/version
```

## 2. Hyprland rule

Add to `~/.config/hypr/hyprland.conf`:

```ini
windowrule {
    name = isolate-hermes-browser
    match:class = ^hermes-browser$
    workspace = 9 silent
}
```

Apply and verify:

```bash
hyprctl reload
hyprctl clients -j
```

Expected: class `hermes-browser`, workspace id/name `9`. Do not use `match:class = chromium`, which catches the user's browser too.

## 3. Point Hermes at the dedicated endpoint

```bash
hermes config set browser.cdp_url http://127.0.0.1:9222
hermes config get browser.cdp_url
```

Browser Use mode resolves `browser.cdp_url` before falling back to local Chrome, so this prevents attachment to the user's ordinary profile.

## 4. Recurring-job contract

Recommended toolsets:

```json
["web", "browser", "terminal", "file"]
```

Prompt clause:

```text
Browser rule: browser_exec is allowed; every call must pass
session="daily-self-study". Prefer web_search/web_extract/curl and use the
browser only for pages that require rendering or defeat direct extraction.
Do not use computer_use or operate the user's everyday Chromium.
```

The session name isolates daemon/tab state across repeated runs. The dedicated CDP endpoint supplies process/profile/workspace isolation.

## 5. End-to-end probe

Run a real browser call using the same session name:

```python
# Testing the isolated Hermes browser
new_tab("https://example.com")
wait_for_load()
print({"title": js("document.title"), "url": js("location.href")})
```

Then inspect:

```bash
hyprctl activeworkspace -j
hyprctl clients -j
```

Pass criteria:

- Probe returns the page title and URL.
- Active user workspace is unchanged.
- Test page belongs to class `hermes-browser` on workspace 9.
- No blank windows appear under the user's normal `chromium` class.

## Diagnostic evidence pattern

When unexpected windows recur, correlate these three sources:

1. `hyprctl clients -j`: exact count, titles, class, PID, workspace.
2. `~/.hermes/logs/agent.log`: matching cron run plus `tool browser_exec completed`.
3. `cronjob action=list`: `last_run_at`/status and enabled toolsets.

A finished browser-use subprocess may leave a browser window behind, so the absence of a live harness daemon does not exonerate the completed cron run.
