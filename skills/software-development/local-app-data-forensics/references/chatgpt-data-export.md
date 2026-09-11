# ChatGPT data export: download, verify, and index safely

Use this workflow when a user asks to retrieve or inspect an OpenAI/ChatGPT account export without loading gigabytes of conversation text into model context.

## Retrieval

1. Search the mailbox for `ChatGPT - Your data export is ready`. With Himalaya v2, structured output uses `--json` (not legacy `--output json`). Gmail IMAP resets are transient; retry the read with bounded backoff.
2. Read the message and extract the signed `chatgpt.com/backend-api/estuary/content?...` URL. HTML-unescape `&amp;` before requesting it. Never print the signed URL.
3. An unauthenticated signed-link request may return HTTP 403. If the user already has a valid `openai-codex` OAuth credential, load its access token from the active profile's `auth.json` and send it as `Authorization: Bearer ...`. Never copy the token to logs, shell history, or chat.
4. Before downloading, request `Range: bytes=0-0` with `Accept-Encoding: identity`. Require HTTP 206 and parse `Content-Range: bytes 0-0/TOTAL`; this discovers the exact size and proves resumability without transferring the object.
5. Resume locally in bounded ranges (for example 256 MiB). For every range:
   - require HTTP 206;
   - require the exact expected `Content-Range`;
   - download to a temporary chunk;
   - verify its byte count;
   - only then append and `fsync` the destination;
   - retry a failed chunk with bounded backoff.

This avoids silently accepting a truncated ZIP that merely begins with `PK`. HTTP 200 plus a ZIP header is not completion evidence.

## Verification

Require all of the following before reporting success:

- local byte size equals server `TOTAL`;
- ZIP central directory opens;
- `ZipFile.testzip()` returns `None` (all member CRCs pass);
- report archive entries and remaining disk space, but do not dump filenames for thousands of private attachments.

## Safe extraction

Compute total uncompressed bytes first and compare with free disk. Reject every member whose resolved destination escapes the extraction root (ZIP-slip defense). Extract to a dedicated directory and verify each output size against `ZipInfo.file_size`.

## Context-efficient conversation indexing

ChatGPT exports may shard conversations across `conversations-000.json`, `conversations-001.json`, etc. The shard count is not the conversation count.

Process one shard at a time locally. Extract only:

- `title`
- `id` / `conversation_id`
- `create_time`
- `update_time`
- `is_archived`
- source shard

Dedupe by conversation ID, retaining the newest update. Write small JSON, CSV, and title-only TXT indexes. Verify raw count, unique count, duplicate count, missing IDs, untitled count, and archived count in code. Send the index file or a short sample; never inject the complete export into model context.

For one selected conversation, extract just that record to a focused file, calculate message/role/character counts, build keyword or chapter anchors locally, and page through only relevant sections. State honestly whether the conversation was read exhaustively or sampled structurally.

## Privacy

- Treat exports as highly sensitive: they include account metadata, conversations, images, and uploaded files.
- Do not expose signed URLs, OAuth tokens, email addresses, attachment IDs, or raw conversation dumps in tool output.
- Do not infer that historical crisis language describes the user's current state; acknowledge the date and check current safety separately when warranted.
