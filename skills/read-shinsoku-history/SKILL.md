---
name: read-shinsoku-history
description: Read and search the user's local Shinsoku transcript history through the read-only JSON CLI. Use when an agent needs to find, summarize, compare, or reference past voice transcripts by date, source application, text, Profile, or entry ID without modifying history or opening SQLite directly.
---

# Read Shinsoku History

Use `shinsoku-history`; never query or modify `history.sqlite3` directly.

## Locate the CLI

Prefer `SHINSOKU_HISTORY_CLI` when set, then `shinsoku-history` on `PATH`.
When working in the Shinsoku repository, allow
`build/Debug/shinsoku-history` or `build/Release/shinsoku-history` as a local
development fallback. On macOS, also check
`/Applications/Shinsoku.app/Contents/MacOS/shinsoku-history`.

If no executable exists, report that the desktop CLI must be built or installed.
Do not replace it with `sqlite3`.

## Query

Start with the smallest useful result set:

```bash
shinsoku-history list --since 2026-08-20 --limit 20
shinsoku-history list --app Mail --query invoice --limit 20
shinsoku-history get 42
```

Use `--before-id` for another page. Parse stdout as JSON schema version 1. Treat
an empty `entries` array as a valid result.

Do not use `--include-meta` or `--include-audio-path` unless the user explicitly
asks for diagnostics or recording paths. Never infer that permission from a
general request to search history.

## Answer

State the date, source-app, and text filters used. Distinguish transcript facts
from an agent summary. Cite local results by history entry ID and creation time
so the user can retrieve the exact record later.

This interface is read-only. Do not promise edits, deletion, or replay through
the skill.
