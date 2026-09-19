# Upgrading the globally-installed OpenClaw CLI (npm pack path)

Verified 2026-09-19: 2026.8.1 → 2026.9.5, gateway healthy afterwards.

## Two different installations — don't confuse them

| | path | who runs it |
|---|---|---|
| source checkout | `~/projects/openclaw` | dev / manual `pnpm openclaw ...` |
| global npm copy | `~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw` (bin symlink `~/.nvm/.../bin/openclaw`) | **the systemd user service** `openclaw-gateway.service` |

The service ExecStart is `<nvm node> .../lib/node_modules/openclaw/dist/index.js gateway --port 18789`. So `git pull` + `pnpm build` in the checkout does NOT change what the live gateway runs — the checkout is only the thing `pnpm openclaw` uses. To upgrade the running gateway you must rebuild the package tarball and reinstall it globally.

Also: `npm config get prefix` = `/usr`, and `npm ls -g` may not list openclaw at all — inspect the nvm node_modules dir directly.

## Procedure

1. `cd ~/projects/openclaw`
2. Clean stale build locks (see Pitfalls).
3. `OPENCLAW_TSDOWN_MAX_OLD_SPACE_MB=7168 pnpm build:package` — background, ~11 min (651s observed), 16 phases. Produces `.js`-format dist for npm (alongside `.mjs` for dev).
4. `pnpm pack --skip-build --allow-unreleased-changelog --pack-destination ~/.openclaw-install`
   - `--skip-build` because step 3 already built.
   - `--allow-unreleased-changelog` is required for a between-releases workspace.
   - Plain root packing is refused: `prepack: plain root packing cannot safely resolve @openclaw/ai from workspace:*`.
   - **Never pack into `/tmp`** — see Pitfalls. The pack script validates integrity (`OpenClaw package tarball integrity passed`); a truncated pack silently drops dist files.
5. Back up the global dir: `cp -a ~/.nvm/.../lib/node_modules/openclaw ~/.openclaw-install/backup-<oldver>/` (~900M, a few seconds).
6. `systemctl --user stop openclaw-gateway`
7. `npm install -g --prefix ~/.nvm/versions/node/v22.22.3 <tgz>`
   - **npm 11 blocks install scripts by default**: it warns `install-scripts 5 packages had install scripts blocked ... openclaw@<ver> (postinstall: node scripts/postinstall-bundled-plugins.mjs ...)`. Either pass `--allow-scripts=openclaw,...` or run the postinstall manually afterwards: `cd <global openclaw dir> && node scripts/postinstall-bundled-plugins.mjs`. A blocked postinstall still reports `EXIT: 0` — check the warning block, not the exit code.
   - Then verify `package.json` version and that `dist/index.js` is the new build.
8. `systemctl --user start openclaw-gateway`, wait ~10s, then `curl -s http://127.0.0.1:18789/healthz` → `{"ok":true,"status":"live"}`.

## Pitfalls hit this time

- **Hermes' terminal runs inside the gateway process**: `openclaw doctor|status|health` are rejected with `Blocked: command or referenced script cannot restart, stop, or uninstall the gateway from inside the gateway process`. Use `curl http://127.0.0.1:18789/healthz` for liveness (`/healthz` and `/health` both return `{"ok":true,"status":"live"}`). Do NOT `curl /` — the control UI is huge and curl hangs until timeout.
- **`/tmp` is a ~1.1G tmpfs**: packing there truncated the tarball (72M instead of ~150-200M, missing dist files), and pack later failed with `Disk quota exceeded`. Keep tarballs and build outputs under `/home`.
- **A failed `openclaw update` leaves a ~2.5G sandbox in `/tmp`**: `/tmp/openclaw-git-admission-*`, one dir per attempt, not cleaned up when the update is killed. Safe to delete; one cleanup took /tmp from 832M to 1.9G free.
- **Stale `.artifacts/dist-artifacts.lock`**: `pnpm build` / `build:package` refuses with `Could not acquire .artifacts/dist-artifacts.lock ... file lock stale`. The lock is deliberately RETAINED when the dir holds `unjoined` or `child-*` files (`child cleanup unverified; retained ...`). Confirm no live tsdown pids (`ps -ef | grep tsdown`), then delete the lock dir plus leftover `plugin-sdk-staging-*` temp dirs.
- **`openclaw update` is the wrong tool here.** It failed with a preflight-worktree bug: it tried to `git worktree add` a `linux-stable` tag commit that wasn't fetched locally → `fatal: Could not reset index file to revision 'HEAD'`. Manually running `git worktree add --detach <dir> <sha>` for the same commit succeeds — the failure lives inside the update pipeline's temporary admission sandbox, not in git.
- **A `sha256sum` vs `git ls-tree` mismatch on tracked files is NOT evidence of local edits** — git uses SHA-1 by default. Compare with `git hash-object <file>`, or trust `git status` + `git diff` after `git update-index --refresh`.
- **The schema-version warning is pre-existing**: the gateway logs `OpenClaw agent database .../openclaw-agent.sqlite uses schema version 19; stop active agents and run openclaw doctor --fix to migrate session identities`. It was there before this upgrade; sessions stay degraded until `doctor --fix` runs with the gateway stopped.
