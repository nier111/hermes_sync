# Hyprland Hyprlang → Lua migration (0.55–0.57)

Use this when an Arch/Hyprland user sees the warning that `.conf`/Hyprlang configuration will be removed.

## Durable facts

- Hyprland 0.55 deprecated Hyprlang in favor of Lua; the normal Lua entrypoint is `~/.config/hypr/hyprland.lua`.
- The active configuration provider is selected when the Hyprland process starts. Check it with `hyprctl systeminfo` (`configProvider: hyprlang|lua`). A plain `hyprctl reload` does **not** switch a running session from Hyprlang to Lua.
- Therefore, leaving both files present and merely reloading can produce a false success: `hyprctl configerrors` may be empty because the old `.conf` is still active.

## Safe migration workflow

1. Snapshot live state before touching the configuration:
   - `hyprctl -j monitors`
   - `hyprctl -j binds`
   - `hyprctl -j workspaces`
2. Timestamp-back up `hyprland.conf`.
3. Convert to `hyprland.lua`. `hyprconf2lua` can be run once with `uvx --from hyprconf2lua hyprconf2lua ...`; use `--check --report` but do not trust its coverage report as runtime validation.
4. Manually inspect high-risk translations:
   - animation declarations;
   - `exec-once` commands involving `cd`, shell chaining, redirection, or backgrounding;
   - monitor scale/position;
   - XWayland scaling;
   - window rules and custom workspace placement;
   - locked/repeating multimedia binds.
5. Run Hyprland's own parser, which selects Lua from the explicit filename:
   `Hyprland --verify-config --config ~/.config/hypr/hyprland.lua`
   Repeat until it prints `config ok`.
6. Optionally perform a real non-destructive runtime test by starting a nested Hyprland instance from the current Wayland session. Use a temporary copy with the entire `hl.on("hyprland.start", ...)` autostart block removed (do not replace it with a fake event name). Start `Hyprland --config /tmp/hyprland-lua-runtime-test.lua`, then verify the new instance using `hyprctl instances` and `hyprctl -i <index> systeminfo`, `configerrors`, and `binds`. Confirm `configProvider: lua`, zero errors, and expected bind count; terminate the tracked test process afterward.
7. Compare pre/post semantic state, not just file syntax: monitor geometry/scale, bind tuples/count, workspaces, and key rules.
8. To switch the real session, restart Hyprland; reload alone is insufficient. If interrupting the user's graphical session is unsafe, configure the next SDDM launch explicitly and leave the current `.conf` in place until logout:
   `Exec=/usr/bin/start-hyprland -- --config /home/USER/.config/hypr/hyprland.lua`
   Back up the package-owned desktop entry first. This override may be replaced by a package update; once Hyprlang removal lands, the default Lua discovery makes the bridge unnecessary.

## Converter pitfalls observed

- `hyprconf2lua` reported 100% coverage yet emitted `hl.animation({ leaf = "global", ... })` without a curve. Hyprland rejected it with `bezier or spring is required`; preserving old `default` semantics required `bezier = "default"`.
- Separate legacy commands such as `cd ~/app`, `./app -d .`, `cd ~` must become one shell command (for example `cd ~/app && ./app -d .`). Conversion may also accidentally collapse `-d .` into `-d.`.
- `luac -p` only checks Lua grammar. It cannot validate Hyprland API calls, event names, option types, or runtime registration; always use `Hyprland --verify-config` and preferably the nested runtime test.
- Emergency-default symptoms (e.g. only a handful of binds and default monitor scale) can occur with an empty `configerrors`; inspect `configProvider` and live state before declaring success.

## Rollback

Keep the original `.conf` and its timestamped backup until the real Lua session has started successfully. If a test changes live state unexpectedly, restore the `.conf`, reload, and verify bind count plus monitor scale before continuing.
