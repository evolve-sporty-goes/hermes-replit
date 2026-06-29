# Sync Script Commit Message Design (v3 — AI removed)

**Status: AI commit messages were REMOVED in the v3 rewrite (2026-06-29).** This document is retained for historical reference only.

## Why AI Was Removed

The sync script previously called OpenRouter per file to generate commit messages. This was removed because:

1. **Latency** — 8-10 seconds per file × 10+ files = 80+ seconds per sync
2. **Fragility** — JSON parse failures on empty/ratelimited API responses caused `python3 -c` to crash
3. **Unnecessary** — a single commit listing all changed files is sufficient and instant
4. **User preference** — user explicitly asked for a "clean short sync from scratch removing ai"

## Current Approach (v3)

Single commit per sync run:
```
auto: 2026-06-29T11:39:31Z — 3 file(s): .hermes_data/state.db .hermes_data/config.yaml scripts/sync
```

Format: `auto: <ISO8601> — <count> file(s): <space-separated relative paths>`

## Historical Implementation (v2 — DO NOT RE-IMPLEMENT)

The old `ai_commit_msg` function used `curl` to OpenRouter with `google/gemini-2.0-flash-001`, `--max-time 8`, `--max_tokens 40`, and an awk-based fallback. It was removed per user direction.
