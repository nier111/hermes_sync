# OpenClaw 2026.8.1 stable migration (verified 2026-09)

Use this when upgrading this machine from the old Git/dev checkout to the stable package release, or when repairing memory after that migration.

## Preflight and backup

- Stop the user Gateway before a consistent full-state archive.
- Back up all of `~/.openclaw`, the user systemd unit, current Git SHA, dirty patch, and modified lockfiles to `~/backups/openclaw/<timestamp>/`.
- Store the archive under `$HOME`, not `/tmp`; verify both archive readability and SHA-256 checksums.
- A full `~/.openclaw` archive is external to OpenClaw's own backup registry, so Doctor may still say no built-in backup is recorded.

## Channel and install-mode trap

A source checkout on branch `main` reports channel `dev`. On that install:

- `openclaw update --tag 2026.8.1` does **not** pin a Git update; `--tag` is ignored for Git mode.
- Preview with the CLI's direct entrypoint if `pnpm openclaw` triggers an unnecessary dependency consistency install:
  `node scripts/run-node.mjs update --channel stable --tag 2026.8.1 --dry-run --json --no-restart`
- `--channel stable` intentionally switches from Git/dev to the stable npm package install.
- Run the real migration with the supported Node 22 runtime and keep the already-stopped service down:
  `openclaw update --channel stable --tag 2026.8.1 --no-restart --yes --json --timeout 1800`

## Repair and plugins

After the core swap:

- Run `openclaw update repair --accept-capabilities --yes --json --timeout 1800` to finish Doctor migrations and converge official plugins.
- 8.1 externalizes several providers. Preserve configured routes by installing/enabling the corresponding official packages (for this host: DeepSeek, llama.cpp, Kimi, and Moonshot as applicable).
- QQBot is tracked by manifest id `openclaw-qqbot`; remove a stale `plugins.entries.qqbot` key after confirming the real plugin is installed. A version pin does not follow latest; use `openclaw plugins update @tencent-connect/openclaw-qqbot@latest --accept-capabilities` when deliberately moving the pin.
- Do not automatically enable intentionally disabled providers (for example OpenRouter with no balance) merely to silence Doctor warnings.

## Active Memory: installed is not enabled

The 8.1 package can ship Active Memory while leaving it disabled. A working setup requires all of:

1. `openclaw plugins enable active-memory --accept-capabilities`
2. Configure `plugins.entries.active-memory.config`, preferably conservative defaults: mode `escalate`, agent `main`, chat types `direct` and `explicit`, query mode `recent`, and a bounded timeout.
3. Set `memory.search.rememberAcrossConversations=true` for private same-agent transcript recall.
4. Ensure the configured embedding model exists. This host uses Ollama `nomic-embed-text`; install it with `ollama pull nomic-embed-text`.
5. Run `openclaw memory status --index --agent main` and allow enough time. The command has poor progress output and may spend 10+ minutes mostly sleeping on sequential Ollama HTTP calls. Inspect the newest `*.memory-reindex-*` staging DB counts/mtime before declaring it hung. Do not kill it merely because CPU is low.
6. Verify `Indexed: N/N`, `Dirty: no`, `Embeddings: ready`, `Vector store: ready`, `Semantic vectors: ready`, and `FTS: ready` with `openclaw memory status --deep --agent main`.
7. Prove retrieval with `openclaw memory search --agent main --query '<known memory>' --json`; status alone is insufficient.

## Service/runtime compatibility

- Stable 2026.8.1 supports Node `>=22.22.3 <23 || >=24.15 <25 || >=25.9`; this host's system Node 26 is outside that declared range.
- Verify the *actual* Gateway executable through `/proc/<MainPID>/exe`, not only the shell CLI version.
- The generated user unit may point `ExecStart` at `/usr/bin/node` even when the package lives under NVM. On this host the verified runtime is NVM Node 22.22.3. Keep the service explicitly pinned to that compatible executable until OpenClaw supports system Node 26.
- Remove stale system-scope Gateway units when the intended deployment is the enabled user unit; two units on port 18789 can restart-loop against each other.

## End-to-end verification

Do not stop at `systemctl is-active`:

- `openclaw gateway status --deep` must report CLI and Gateway 2026.8.1, connectivity OK, and the correct package root.
- Run a real `openclaw agent --agent main -m '<fixed response probe>' --json` and verify provider/model/result.
- Check journal lines for QQ access-token success, WebSocket connected, and Gateway READY.
- Check session SQLite counts and run a known-memory search.
- Long legacy main sessions can be extremely expensive: a one-line probe on a 1,000+ message session can send hundreds of thousands of input tokens. Prefer a fresh session once cross-conversation memory is working.
