# Stable upgrade and long-term memory activation (2026.8.1+)

Use this when upgrading a source-checkout OpenClaw installation to a stable package release and validating the new memory stack.

## Safe upgrade sequence

1. Check disk space on both the state filesystem and `/tmp`; inspect service ownership, current channel, dirty Git state, Node versions, and target `engines.node`.
2. Stop the managed Gateway before the consistent backup. Back up the complete state directory, service unit, current Git SHA, uncommitted binary patch, and modified files. Verify archive readability and checksums before proceeding.
3. Run update status and a direct CLI dry-run. On a Git checkout, `--tag <version>` alone is ignored: the checkout remains on its Git channel. To move from `dev/main` to stable, explicitly use `openclaw update --channel stable --tag <version>`; stable switches install ownership to the package release.
4. Run the update with `--no-restart` when the Gateway was stopped manually. Then run `openclaw update repair --accept-capabilities --yes` to converge Doctor migrations and configured plugins.
5. Rebuild the user-level Gateway service for the new install owner. Detect and remove only a proven stale competing system-level unit; never leave two enabled units binding the same port.
6. Verify CLI version, Gateway-reported version, actual `/proc/<pid>/exe`, listener, deep status, journal readiness, channel connection, and one real agent call.

## Active Memory activation

The 2026.8.1 package may ship Active Memory disabled even though memory-core, Dream Diary, and recall data exist.

Recommended personal setup:

- Enable `active-memory` with capability consent.
- Configure `mode: "escalate"`, agent allowlist, private `direct`/`explicit` chat types, `queryMode: "recent"`, and a bounded timeout.
- Explicitly enable `memory.search.rememberAcrossConversations` for the personal agent.
- Ensure the configured embedding model actually exists at the provider. For Ollama, pull the configured embedding model before indexing.
- Run a full memory index and then verify `Dirty: no`, `Embeddings: ready`, `Semantic vectors: ready`, `FTS: ready`, and all sources indexed.
- Perform a real semantic search for a known personal fact and inspect provenance, not just index counts.

## Long reindex behavior

A first full index can create more than a thousand chunks and take 10+ minutes with local Ollama. The CLI may print no progress while waiting on embedding HTTP calls, and the process can spend most time sleeping.

Do not classify it as hung from low CPU alone. Run it in the background with a generous timeout and check the newest `*.memory-reindex-*` staging database sparingly: growing source/chunk/cache counts or recent mtime means progress. Let the command publish the staging DB atomically. Only terminate when counts and mtime remain genuinely unchanged and provider/log evidence shows no work.

## Migration checks worth preserving

- Provider integrations formerly bundled may become official external plugins. Install and enable packages for configured routes rather than deleting model/auth configuration.
- Plugin IDs can differ from npm package names; remove only confirmed stale legacy `plugins.entries.<old-id>` keys after the replacement plugin loads.
- Exact plugin pins do not follow registry latest. The updater will state the explicit package spec required to change tracking intent.
- New DM policy validation may turn an old contradictory `open` + non-wildcard allowlist into dropped DMs. Prefer `pairing` unless the operator explicitly wants public access.
- A service generator can select a system Node that starts successfully but is outside the release's declared engine range. Verify the actual runtime executable and version, not only the CLI shell version.

## Final acceptance evidence

A successful migration has all of the following:

- verified rollback archive;
- target CLI and Gateway versions match;
- one service owner and one listener;
- configured primary model returns a real reply;
- required channels report connected/READY;
- Active Memory plugin loaded;
- memory index complete and clean with semantic vectors ready;
- known-fact search returns the expected memory with provenance;
- remaining warnings are explicitly classified as intentional disabled integrations, optional auth, or real follow-up work.
