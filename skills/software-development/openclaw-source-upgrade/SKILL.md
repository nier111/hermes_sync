---
name: openclaw-source-upgrade
description: Upgrade OpenClaw source checkout to npm global install.
---

# OpenClaw source-checkout → npm global upgrade

Reproducible path from `~/projects/openclaw` (git checkout) to the npm-installed global gateway version. Skips the built-in `openclaw update` command (it clones a git-admission sandbox to `/tmp` and runs `git worktree add` with the worktree path **inside** the git-dir, which git refuses — see "Why not `openclaw update`" below).

## When this applies

- User maintains `~/projects/openclaw` as a git checkout and wants the live systemd gateway to run a fresh build.
- Live gateway is installed as npm global at `~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw/`.
- systemd unit is `~/.config/systemd/user/openclaw-gateway.service` with `ExecStart` pointing at the npm-installed `dist/index.js gateway --port 18789`.

## What this is NOT for

- npm-tag-based upgrades (`openclaw update --channel stable`). Use the built-in command for that.
- Workplaces where the live gateway is itself run from `~/projects/openclaw/dist/` (see the `.bak` of the unit file for that style — just `systemctl restart openclaw-gateway` after `pnpm build`).
- Touching anything in `~/projects/openclaw/.openclaw/` or `~/.openclaw/` other than doctor migrations — those are runtime state.

## Steps

### 1. Clear stale `.artifacts/dist-artifacts.lock/`

If `pnpm build:package` fails with `file_lock_stale` referencing `.artifacts/dist-artifacts.lock/owner.json`:

1. Verify the owner PID is dead: `ps -p <pid-from-owner.json>` returns nothing.
2. Verify no detached descendants are running: `pgrep -fa "<pid>"` empty.
3. `rm -rf ~/projects/openclaw/.artifacts/dist-artifacts.lock ~/projects/openclaw/.artifacts/plugin-sdk-staging-*`
4. Leave `~/projects/openclaw/.artifacts/build-all-cache/` alone (it's the persistent build cache).

The lock fails-closed by design — see `scripts/lib/dist-artifact-ownership.mts` — so it requires manual removal even when the owner PID is dead.

### 2. Clear `/tmp` of stale openclaw-git-admission sandboxes

Each failed `openclaw update` invocation leaves a 2-3 GB bare-repo clone under `/tmp/openclaw-git-admission-*/repository.git/`. On tmpfs that's enough to break tar packing mid-write. If `/tmp` is below ~1.5 GB free before pack:

```bash
du -sh /tmp/openclaw-git-admission-* 2>/dev/null
rm -rf /tmp/openclaw-git-admission-*
df -h /tmp   # verify 1.5 GB+ free
```

### 3. `pnpm build:package`

```bash
cd ~/projects/openclaw
export OPENCLAW_TSDOWN_MAX_OLD_SPACE_MB=7168   # bump heap; default OOMs on dts generation
pnpm build:package
```

Wall time ~10 min on an 8-core / 8 GB machine. The 6 dts-extension tsdown invocations vary 36-180 s each; the slow phase is `write-unified-entry-dts` (~7 min). Output goes to `dist/`, in **CJS `.js`** format (not the `.mjs` format `pnpm build` emits — the latter is for dev only).

Verify success: `tail -3` of the log must end with `phase timings: ... total <duration>` and exit code `0`. Check that `dist/*.js` exists (not just `.mjs`).

### 4. Pack the tarball

```bash
node scripts/package-openclaw-for-docker.mjs \
  --allow-unreleased-changelog \
  --skip-build \
  --output-dir /home/sato/.openclaw-install \
  --output-name openclaw-<version>.tgz
```

Do **NOT** use plain `pnpm pack` — the prepack script refuses root packing (`workspace:*` rewrites break `@openclaw/ai`). The Docker pack script handles `@openclaw/ai` bundling.

Write to a real-filesystem path, not `/tmp` — the unpacked tarball can exceed tmpfs free space and fail mid-write with "Disk quota exceeded" on individual files. `/home/sato/.openclaw-install/` is fine.

Verify integrity: `check-openclaw-package-tarball:` line ending in `OpenClaw package tarball integrity passed.` in the log.

### 5. Back up the current global install

```bash
mkdir -p /home/sato/.openclaw-install/backup-<old-version>
cp -a ~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw/. \
      /home/sato/.openclaw-install/backup-<old-version>/
```

`cp -a` preserves symlinks and perms. 5-10 s for ~900 MB. Don't skip this — it is the rollback path.

### 6. Stop the live gateway

```bash
systemctl --user stop openclaw-gateway
```

Confirm: `Active: inactive (dead)` in `systemctl --user status`, port 18789 not in `ss -ltn`, main PID gone.

### 7. Install the new tarball

```bash
npm install -g --prefix /home/sato/.nvm/versions/node/v22.22.3 \
  /home/sato/.openclaw-install/openclaw-<version>.tgz
```

Newer npm (≥ 11) **blocks the `postinstall` script by default**. The install will warn:

```
npm warn install-scripts ... openclaw@<version> (... postinstall: node scripts/postinstall-bundled-plugins.mjs ...)
```

Run the postinstall manually immediately after install:

```bash
cd ~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw
node scripts/postinstall-bundled-plugins.mjs
```

Or re-run the install with `--allow-scripts=openclaw` to do it inline. The postinstall prunes legacy dist files; skipping it leaves a half-installed package.

### 8. Start the gateway and verify

```bash
systemctl --user start openclaw-gateway
sleep 8   # gateway takes a few seconds to become ready after restart
curl -s http://127.0.0.1:18789/health
```

Expect `{"ok":true,"status":"live"}` and HTTP 200. `systemctl --user status` should show `Active: active (running)` with the new main PID.

### 9. Run `doctor --fix`

```bash
systemctl --user stop openclaw-gateway
cd ~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw
node dist/index.js doctor --fix
systemctl --user start openclaw-gateway
```

Doctor --fix needs the gateway stopped because it modifies SQLite databases (state DB and agent DBs) that the live gateway holds open.

`doctor --fix` automatically resolves: Skill Workshop relocations, legacy agent database registry schemas, plugin manifest mismatches. It **does not** update plugin npm packages — see next step.

### 10. Update drifted plugins

After restart, `doctor` typically reports 1-4 official plugins still on the prior version (e.g. `deepseek`, `kimi`, `llama-cpp`, `moonshot`). Update each:

```bash
cd ~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw
for p in deepseek kimi llama-cpp moonshot; do
  node dist/index.js plugins update $p
done
```

These updates hot-reload — `Applied plugin updates in Gateway generation N` — no gateway restart needed.

## Why not `openclaw update`

The built-in command's `git` mode (default for source checkouts):

1. `git fetch origin` — fine.
2. Clones a git-admission sandbox to `/tmp/openclaw-git-admission-<id>/repository.git` — leaves a 2-3 GB bare repo.
3. Runs `git -C <repo> --git-dir=<sandbox> worktree add --detach <sandbox>/.artifacts/.openclaw-update-preflight-<id>/worktree <sha>`.

Step 3 fails because the worktree path is **inside** the `--git-dir` directory; git refuses. The error is masked as `8 files: unable to write` followed by `fatal: Could not reset index file to revision 'HEAD'`.

The `--channel dev` / `--channel stable --tag <x>` paths have different layouts; `--channel dev` may work because it skips the worktree preflight. But for a normal `update` against git main, the preflight is mandatory.

Don't waste time debugging this — go through `pnpm build:package` → tarball → npm install.

## Failure recovery

- **`file_lock_stale` on `pnpm build:package`** → see step 1.
- **`Disk quota exceeded` mid-pack on `/tmp`** → see step 2; repack to a real-FS output dir.
- **`postinstall` warning "install scripts blocked"** → see step 7; run postinstall manually.
- **Gateway stays down after install** → check `journalctl --user -u openclaw-gateway.service -n 50`; common cause is the postinstall not running, leaving dist in an inconsistent state. Run postinstall, restart.
- **Agent DB schema warnings persist after `doctor --fix`** → confirm gateway was actually stopped before running `doctor --fix`; the command refuses to modify DBs while gateway holds the lease.
- **Roll back to the prior version** → `cp -a /home/sato/.openclaw-install/backup-<old-version>/. ~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw/` then `systemctl --user restart openclaw-gateway`. 5-second rollback.

## Environment knobs

- `OPENCLAW_TSDOWN_MAX_OLD_SPACE_MB=7168` — bump heap for `pnpm build`/`build:package`. Without it, default heap OOMs on the dts-extension tsdown invocations on 8 GB machines.
- `--max-old-space-size=3795` — already set in the systemd unit for the gateway. Don't change it without checking the live workload.

## Files / paths reference

| What | Path |
|---|---|
| Source checkout | `~/projects/openclaw/` |
| Build output | `~/projects/openclaw/dist/` |
| Stale lock dir | `~/projects/openclaw/.artifacts/dist-artifacts.lock/` |
| Live npm install | `~/.nvm/versions/node/v22.22.3/lib/node_modules/openclaw/` |
| Live gateway symlink | `~/.nvm/versions/node/v22.22.3/bin/openclaw` |
| systemd unit | `~/.config/systemd/user/openclaw-gateway.service` |
| Rollback backup | `/home/sato/.openclaw-install/backup-<old-version>/` |
| Tarballs | `/home/sato/.openclaw-install/openclaw-<version>.tgz` |
| Runtime state | `~/.openclaw/` (state DB, agent DBs, plugin npm projects) — do not touch during upgrade |
| `/tmp` admission leftovers | `/tmp/openclaw-git-admission-*/` — safe to delete |

## Total wall time budget

- `pnpm build:package`: 10-11 min
- `package-openclaw-for-docker.mjs --skip-build`: 3 min
- `npm install -g` + manual postinstall: 30 s
- `doctor --fix`: 20 s
- Plugin updates: 30 s × 4 = 2 min
- Total: ~16 min for a clean run, ~30 min if a stale-lock or `/tmp`-full detour happens.