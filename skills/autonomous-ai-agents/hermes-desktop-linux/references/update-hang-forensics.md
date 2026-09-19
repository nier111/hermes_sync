# Diagnosing a hung `hermes update` / desktop rebuild

Symptom: `hermes update --yes` prints "checking if desktop app needs rebuilding"
and then nothing for 10+ minutes. Nothing is corrupt, and the update's main work
(git pull, package install, gateway restart) has already happened by this stage —
only the desktop rebuild is stuck.

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

Rebuild only when the GUI app is actually wanted, with mirrors in the env:
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
  update tries the rebuild again.
