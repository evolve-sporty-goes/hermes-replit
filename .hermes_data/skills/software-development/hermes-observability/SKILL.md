---
name: hermes-observability
description: "See what Hermes is doing in real time and after the fact — tool progress, browser snapshots, verbose modes, timestamps, session replay. Load when the user asks 'show me what you're doing', 'more detail on browser actions', 'full snapshots', 'why didn't I see that', or complains about too much/little terminal output."
version: 1.0.0
author: OWL
platforms: [linux, macos, windows, replit]
metadata:
  hermes:
    tags: [observability, debugging, terminal, display, browser]
---

# Hermes Observability

Control how much you see of Hermes's tool calls, browser actions, and intermediate state — both live in the terminal and in retrospect.

## Quick Reference

| Goal | Config key | Value |
|------|-----------|-------|
| See every tool call in real time | `display.tool_progress` | `all` |
| See full arguments + full results | `display.tool_progress` | `verbose` |
| Keep /verbose working in-session | `display.tool_progress_command` | `true` |
| Add timestamps to every line | `display.timestamps` | `true` |
| Force verbose for browser only | `display.tool_progress_overrides.browser` | `verbose` |
| Browser: get full (untruncated) snapshots | Ask agent for `browser_snapshot(full=true)` | — |
| Review past browser actions | `session_search(query="browser_")` | — |
| Replay a full session | `hermes sessions export <id> <path>` | — |

## How It Works

### tool_progress modes

`display.tool_progress` controls how tool calls appear in the CLI/MUI:

- `off` — silent, only the final assistant response appears.
- `new` — breadcrumb appears for new tool calls as they happen.
- `all` — every tool call shows name + arguments + result inline.
- `verbose` — full arguments + full result (no truncation of tool output).

Toggle mid-session with `/verbose` (CLI) — requires `display.tool_progress_command: true`.
The cycle is: `off → new → all → verbose → off`.

### Per-tool overrides

`display.tool_progress_overrides` is a dict mapping toolset name to mode. Use it to dial one toolset up/down without affecting others:

```yaml
tool_progress_overrides:
  browser: verbose      # full browser snapshots every call
  terminal: verbose      # full command output
  web: new               # minimal web tool output
```

### Timestamps

`display.timestamps: true` prepends a timestamp to every output line. Helps diagnose slow operations and replay timing.

### Browser-specific: full snapshots

By default browser snapshots are truncated at 8000 chars. To get the full accessibility tree at any point, call `browser_snapshot(full=true)`. The agent can also be instructed mid-session to always request full snapshots.

For true "watch the browser live" (video), you need a VNC-capable provider (Camofox with `ENABLE_VNC=1`, or local Chromium via CDP). See `references/browser-live-view.md`.

## Linked References

- `references/browser-live-view.md` — VNC/live-video setup for watching the browser in real time.

## Setup

```bash
hermes config set display.tool_progress_command true
hermes config set display.tool_progress verbose
hermes config set display.tool_progress_overrides.browser verbose
hermes config set display.timestamps true
```

Then `/reset` to start a fresh session.

To dial back mid-session: type `/verbose` to cycle, or `hermes config set display.tool_progress all`.

## Pitfalls

1. **`tool_progress: verbose` is loud.** Browser snapshots can be hundreds of lines each. If you only need to see browser actions, use `tool_progress: all` globally + `tool_progress_overrides.browser: verbose` to avoid drowning in read_file output.

2. **Mid-session config edits need `/reset`.** `display.options are read at startup. Editing `config.yaml` mid-session has no effect until the next session.

3. **`tool_preview_length` is NOT snapshot truncation.** That controls how long a command/path string can be before ellipsis. It does NOT affect snapshot truncation (which is fixed at 8000 chars in the tool, not configurable).

4. **Gateway platforms suppress tool progress.** Signal, in particular, does not display progress bubbles even when `tool_progress` is set. Per-platform: `platforms.telegram.tool_progress: off` etc.

5. **`/browser` slash command** (in the skill list as "Open CDP browser connection") connects a live local Chromium for browser tool use — different from controlling display verbosity.
