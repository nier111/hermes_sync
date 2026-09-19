# Diagnosing a hung `hermes update` / desktop rebuild

Symptom: `hermes update --yes` prints "checking if desktop app needs rebuilding"
and then nothing for 10+ minutes. Nothing is corrupt — the stall is the desktop
rebuild, not the update. Establish how far the update actually got from its
receipt (`~/.hermes/logs/update_receipts/latest.json`) rather than assuming the
git / package / gateway stages already ran, and confirm WHICH pid is doing the
work: when systemd restarted the gateway mid-update, the CLI the user is watching
stopped being the process that was building, and a new update process took over.

## Walk the process tree
The process is not deadlocked internally: each layer blocks reading its child's
stdout (`wchan: anon_pipe_read`). So walk downward to the deepest process and
inspect that one.

```
ps -ef | grep -E "hermes update|hermes_cli.main desktop|npm ci|node install.js" | grep -v grep
ps --ppid <pid> -o pid,stat,etime,cmd --no-headers   # repeat, going down
cat /proc/<pid>/wchan                                # anon_pipe_read = waiting on a child
```

Expected chain:
`hermes update` → `python -m hermes_cli.main desktop --build-only` → `npm ci` →
`node install.js` (cwd `apps/desktop/node_modules/electron`).

## Whose environment is it running in?
The rebuild inherits the env of the process that spawned it, which is often NOT
your shell's:
```
cat /proc/<updatepid>/environ | tr '\0' '\n' | grep -iE 'proxy|mirror'
cat /proc/<updatepid>/environ | tr '\0' '\n' | grep -iE 'OPENCLAW|HERMES'
```
No proxy vars = a systemd-launched update going direct to GitHub, i.e. the stall
is an environment bug, not a download bug. Launcher markers (e.g.
`OPENCLAW_NODE_UPDATE_RESPAWNED=1`) also tell you the update was started by the
other agent rather than by the user's own shell — worth knowing before blaming
one side. Also walk the parent chain (`ps -o ppid=`) rather than assuming which
agent or unit owns it.

## Confirm stalled, not merely slow
```
du -sh ~/.hermes/hermes-agent/apps/desktop/node_modules    # a few MB = nothing downloaded yet
ss -tnp | grep "pid=<node pid>"                            # one ESTAB :443 to a GitHub IP (185.199.x.x)
```

A live connection with zero byte growth over several minutes = the @electron/get
download is wedged (GitHub releases over a CN network). `strace` is typically not
installed on this machine — reading `/proc` and `ss` is sufficient and cheaper.

## Recover
Kill children BEFORE parents; parents are parked reading the child's pipe, so
killing a parent first leaves orphans.

```
kill -TERM <node install.js>
kill -TERM <npm ci>
kill -TERM <desktop --build-only>
kill -TERM <hermes update>
```

`npm ci` rolls back its staging tree, so `node_modules` shrinks back (e.g. 16M →
8K). That is npm's own rollback, not damage.

Rebuild only when the GUI app is actually wanted. Prefer fixing the environment
the updater ACTUALLY runs in (shared env file + unit drop-in + `daemon-reload` +
restart from an outside shell — see the SKILL.md section on the update's desktop
stage): per-run exports cannot reach a systemd-launched update, so the same hang
returns on every subsequent update. Once the proxy is in the unit's env the whole
chain completes on its own — `node_modules` climbs past a few MB, electron's
`dist/` fills out (~300MB) and `apps/desktop/build/install-stamp.json` is
written. For a one-off manual rebuild, mirror vars in the env are enough:
```
export ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
export ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/
hermes desktop --build-only        # builds + writes the stamp + exits
```

## State to check after killing it
- Gateway restart stage already ran: `systemctl --user is-active hermes-gateway`
  (plus `hermes-gateway-friend` / `hermes-gateway-gf` on this machine) and a
  fresh Main PID / uptime in `systemctl --user status`.
- Code landed: `git -C ~/.hermes/hermes-agent log --oneline -3` — the upstream
  commit plus any carried local commits.
- Health: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/healthz`
  (the per-service HTTP port may return 502 while `/healthz` on the gateway port
  answers 200 — port presence is not liveness).
- Rebuild stamp: `~/.hermes/desktop-build-stamp.json` decides whether the next
  update tries the rebuild again; `apps/desktop/build/install-stamp.json`
  (`commit`, `builtAt`, `dirty`) records the build that DID succeed.
- Update receipt: `~/.hermes/logs/update_receipts/latest.json` (plus a dated
  `update_<ts>_<pid>.json`). Killing the desktop stage does not spoil the update:
  it still finishes and writes `outcome: success`, `exit_code: 0`,
  `stop_reason: "completed at command boundary"`. Confirm the receipt exists and
  check `plan.runtimes[].code_sha` — `null` means that profile's gateway was not
  restarted and is still running old code.
