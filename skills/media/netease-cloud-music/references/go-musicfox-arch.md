# go-musicfox on Arch Linux

## Choosing and installing the package

1. Detect the existing AUR helper before suggesting commands: `command -v paru; command -v yay`. Use the installed helper rather than adding a duplicate.
2. `go-musicfox-bin` is the prebuilt release; `go-musicfox-git` builds current upstream master. Keep official dependencies such as `mpv` conceptually separate (`sudo pacman -S mpv`).
3. Before switching to a git build, use `yay -G go-musicfox-git` and inspect the PKGBUILD. Confirm the source points at `go-musicfox/go-musicfox` and review build/package actions.
4. If background `yay` builds successfully but blocks at nested sudo, retain the generated package and install with direct `sudo pacman -U /path/to/pkg.tar.zst`. If package variants conflict, verify user config/database paths are not package-owned before removing the old variant.

## Native NetEase quality versus substituted sources

Relevant `~/.config/go-musicfox/config.toml` settings:

```toml
[player]
engine = "mpv"
songLevel = "lossless" # or hires when account/catalog permits

[unm]
enable = false
```

- With UNM disabled, MusicFox requests the NetEase source according to account entitlement and catalog availability. The configured level is a preference; the service may downgrade it.
- Enabling UNM can substitute matching tracks from Kuwo/Kugou/Migu/QQ. Do not describe those as NetEase-native files.
- Prefer `lossless` for normal listening and `hires` selectively. `jyeffect`, `sky`, and `jymaster` are special processed/master tiers and are not automatically more faithful for ordinary stereo playback.
- Verify downloaded files with `ffprobe` (codec, sample rate, raw bit depth, bitrate). A FLAC container alone does not prove the source was never transcoded.

## Diagnosing WebView login crashes

Known signature in go-musicfox 5.1.0 on Linux with WebKitGTK 4.1/GTK3:

1. Log shows transient token-refresh failures through the proxy, then `使用 WebView Cookie 登录成功`.
2. Immediately afterward GLib reports invalid/NULL object assertions and the process dies with `SIGSEGV`.
3. Stack includes `internal/webkitgtk.GObjectUnref` and `login_webview_linux.go`.
4. The config Cookie can still be empty because the crash occurs between success detection and persistence.

Root cause: GTK3 owns/destroys the floating WebView/window references; release 5.1.0 also deferred `GObjectUnref`, causing a use-after-free during WebView teardown. Upstream master removed those extra unrefs for legacy WebKitGTK APIs.

Validated recovery pattern:

- Compare the installed release source against current upstream `internal/ui/login_webview_linux.go`; do not merely assume an update contains the fix.
- Switch from `go-musicfox-bin` 5.1.0 to a `go-musicfox-git` build containing the legacy-API ownership fix.
- Verify `musicfox --version` reports a post-release git revision, the old conflicting package is absent, and config/database remain present.
- Login must then be repeated by the user because credentials and QR/web authentication require user interaction. Confirm success afterward by checking that `main.account.neteaseCookie` is non-empty without printing its contents and that the account API recognizes the session.

Paths:

- Config: `~/.config/go-musicfox/config.toml`
- Database: `~/.local/share/go-musicfox/db/musicfox.db`
- Log: `~/.local/state/go-musicfox/log/musicfox.log`

Do not record a particular git commit/version as permanently required; inspect current upstream and installed versions because this bug should disappear from future releases.
