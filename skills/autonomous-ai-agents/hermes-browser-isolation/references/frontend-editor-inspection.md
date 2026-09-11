# Inspecting a web editor without touching the user's browser

Use this when the user asks whether a live web input behavior comes from the site, the browser, or an extension, but their everyday Chromium was not launched with CDP.

## Evidence ladder

1. Identify the real window and process without changing focus:
   - `hyprctl clients -j` → workspace, class, title, PID.
   - Read `/proc/<pid>/cmdline` → profile, proxy, and whether `--remote-debugging-port` exists.
   - `ss -ltnp` → verify which PID owns any CDP port. Never infer that a known port belongs to the user's browser.
2. If the user's browser has no CDP, do not restart it merely to inspect DOM. Use the dedicated isolated Chromium as a clean control, preferably loading the same site/version.
3. Check extensions in the everyday profile separately:
   - Resolve localized manifest names from `_locales/*/messages.json`.
   - Review `content_scripts.matches` and `host_permissions` for the target site or `<all_urls>`.
   - Reproduce in the isolated profile without those extensions. A matching result rules out the extension as the necessary cause.
4. Inspect the actual editor DOM, not only screenshots:
   - Distinguish visible `contenteditable` editors from hidden fallback `<textarea>` elements.
   - Record framework markers such as `ProseMirror`, Lexical, or Slate and the initial `innerHTML`.
5. Verify the transformation dynamically and incrementally:
   - Focus the editor, clear it, insert one character at a time, and capture `innerHTML` after each character.
   - Include likely trigger characters such as a trailing space or Enter. Markdown input rules often transform only after the delimiter is closed and the next boundary is typed.
   - Look for semantic DOM changes (`<em>`, `<strong>`, lists, code nodes), not just visual font style.
6. Clean the isolated composer after testing and verify it is empty. Never submit the test message.

## Direct CDP probe

When browser helpers are attached to the wrong tab, query `http://127.0.0.1:<port>/json`, select the exact page target, and connect to its `webSocketDebuggerUrl`. Chromium may reject arbitrary WebSocket Origins with HTTP 403; a local automation client can omit the `Origin` header (`origin=None`) rather than weakening Chromium with a broad `--remote-allow-origins=*` launch flag.

If the default Python lacks a WebSocket client but the Hermes browser-use environment already provides `websockets`, run the probe with that environment's Python. Treat environment paths as discoverable state, not constants.

## Interpretation

A rich editor framework alone proves only that the site uses structured editing; it does not prove a particular Markdown shortcut. The decisive evidence is a reproduced transition such as:

```html
<p>*2*</p>
```

becoming, after a trailing space:

```html
<p><em>2</em> </p>
```

That transition demonstrates a site-side input rule. If it also reproduces in the extension-free isolated profile, the browser extension is not required for the behavior.
