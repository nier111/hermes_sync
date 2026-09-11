# Major stable upgrade and Active Memory bring-up

Use for a substantial OpenClaw upgrade where state preservation, install-channel migration, plugin convergence, and memory verification matter.

## 1. Preflight and verified backup

Before stopping the gateway, record version, install kind/channel, service ownership, working-tree changes, state size, free disk, and `/tmp` capacity.

For a source checkout, preserve local changes separately (`git diff --binary`, current SHA, changed files). For state, stop the gateway for SQLite consistency and archive the complete state directory outside `/tmp`; verify both archive readability and checksums before proceeding. Automatic config `.bak` files are not a full backup.

## 2. Understand channel semantics

- A checkout on `main` is the `dev` channel.
- `--tag <version>` is ignored by the Git update flow.
- `--channel stable` converts a Git/source deployment to the stable package install path; `--channel dev` retains a moving source checkout.
- Always use `update status --json` and `update --dry-run --json` before a major channel switch.

Use the supported updater rather than manually overlaying package trees. Keep the gateway offline with `--no-restart` when service ownership or runtime selection needs operator inspection.

## 3. Node and service verification

Do not infer runtime compatibility from “the process starts.” Read the target package's Node engine constraint and compare both the invoking Node and the service's recorded executable. After service regeneration, verify:

```bash
openclaw gateway status --deep
pid=$(systemctl --user show openclaw-gateway.service -p MainPID --value)
readlink -f /proc/$pid/exe
```

A generated unit can still select a system Node different from the updater's Node. Resolve that deliberately, then verify CLI version, gateway version, listener, process executable, and restart-loop count.

Also detect duplicate system- and user-scope units before restart; keep one proven owner to avoid port contention.

## 4. Doctor and plugin convergence

A core swap can succeed while plugin convergence requires capability review. Follow with:

```bash
openclaw update repair --accept-capabilities --yes --json
```

Only accept the exact reviewed capability surface. Provider/channel plugins may move from bundled to official external packages; preserve configured routes by installing/enabling the new official owners instead of deleting model configuration. Remove stale legacy plugin keys only after the replacement plugin is loaded and its channel is verified.

For a pinned plugin, ordinary `plugins update <id>` may correctly leave it pinned. Use the explicit package selector requested by CLI output when intentionally moving it to a tracked latest line.

## 5. Active Memory is not necessarily active after upgrade

Check `openclaw plugins list`: bundled Active Memory can be installed but disabled. A conservative personal setup is:

- plugin enabled;
- mode `escalate`;
- selected personal agent(s) only;
- private direct and explicit UI conversations only;
- `memory.search.rememberAcrossConversations=true`;
- `queryMode=recent`, with a bounded timeout;
- no dedicated recall model unless deliberately configured.

If using Ollama embeddings, verify the configured model actually exists before indexing. Pull the model, then run a full index and allow enough time for every memory and session source. Large first indexes may spend many minutes quietly waiting on sequential embedding HTTP calls; assess staging-file growth and embedding-cache counts before declaring a deadlock.

Completion criteria:

```text
Indexed: N/N files
Dirty: no
Embeddings: ready
Vector store: ready
Semantic vectors: ready
FTS: ready
```

Then run a real `memory search` query for a known personal fact and confirm relevant snippets, provenance, and mixed vector/text scores.

## 6. End-to-end verification

A successful upgrade report is insufficient. Verify:

- CLI and gateway report the same target version;
- gateway connectivity and listener are healthy;
- the main provider returns an exact requested test string;
- transcript/session event counts remain nonzero;
- channel logs show authenticated connection and READY;
- Active Memory is loaded;
- full index health is green;
- a known memory query returns the expected historical facts.

Record non-blocking warnings separately (expired optional OAuth, intentionally disabled plugins, stale unused channel config). Do not report them as upgrade failure, but do not hide them.