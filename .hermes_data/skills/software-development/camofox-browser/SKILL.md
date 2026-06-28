---
name: camofox-browser
description: "Camofox Browser server: headless anti-detection browser automation via REST API for AI agents. Install, start, and use the camofox-browser server (port 9377) for stealth web scraping, screenshots, and multi-step page interaction."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [camofox, browser, server, automation, anti-detection, api]
    related_skills: [camoufox]
---

# Camofox Browser Server

Headless browser automation server with anti-detection, accessibility snapshots, element refs, session isolation, and search macros. Runs as a REST API server on port 9377.

## When to Use

- User asks to start/run camofox-browser server
- User needs browser automation via REST API (create tab, navigate, snapshot, click, type)
- User wants screenshots of web pages via API
- User wants stealth browser access without exposing fingerprints
- Don't use for: direct Playwright scripting (use the `camoufox` skill instead), or browserless/chromium alternatives

## Architecture

```
Agent -> REST API (port 9377) -> camoufox-js -> Camoufox (Firefox fork)
```

The server manages Camoufox instances via `camoufox-js`. It expects a Camoufox bundle at a path set via `CAMOUFOX_EXECUTABLE`. The bundle must include `properties.json`, `version.json`, and `fontconfig/` (directory).

## Quick Start

```bash
# Clone
git clone https://github.com/jo-inc/camofox-browser.git
cd camofox-browser

# Install deps (use public registry if behind a proxy)
npm install --registry=https://registry.npmjs.org --ignore-scripts

# Set env and start
export CAMOUFOX_EXECUTABLE="/path/to/camoufox-bundle/camoufox"
export CAMOFOX_PORT=9377
export CAMOFOX_CRASH_REPORT_ENABLED=false
node server.js
```

Server starts at `http://localhost:9377`.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CAMOUFOX_EXECUTABLE` | (required) | Path to the camoufox binary (must be a bundle with properties.json + version.json + fontconfig/) |
| `CAMOFOX_PORT` / `PORT` | 9377 | Server port |
| `CAMOFOX_CACHE_DIR` | `~/.cache/camoufox` | Managed cache (symlinks to bundle) |
| `CAMOFOX_CRASH_REPORT_ENABLED` | true | Set `false` to disable anonymized telemetry |
| `CAMOFOX_API_KEY` | (optional) | Bearer token for sensitive routes |
| `CAMOFOX_ACCESS_KEY` | (optional) | Superkey — gates all routes except /health |
| `CAMOFOX_ADMIN_KEY` | (optional) | Required for /stop endpoint |
| `BROWSER_IDLE_TIMEOUT_MS` | (optional) | Idle timeout before browser shuts down |
| `SESSION_TIMEOUT_MS` | 600000 | Per-user session inactivity timeout |
| `MAX_CONCURRENT_PER_USER` | 3 | Max concurrent browser actions per user |
| `MAX_SESSIONS` | 50 | Max simultaneous sessions |

## Bundle Requirements

The `CAMOUFOX_EXECUTABLE` path must point to a Camoufox bundle containing:

```
camoufox              # executable binary
properties.json       # browser properties
version.json          # version info
fontconfig/           # font configuration directory (symlink OK)
```

If your bundle has `fontconfigs/` (plural), create a symlink:

```bash
ln -s /path/to/bundle/fontconfigs /path/to/bundle/fontconfig
```

## API Workflow

### 1. Health Check

```bash
curl http://localhost:9377/health
```

### 2. Create a Tab

```bash
curl -X POST http://localhost:9377/tabs \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "sessionKey": "task1", "url": "https://example.com"}'
```

Returns: `{"tabId": "abc123", "url": "..."}`

### 3. Navigate

```bash
curl -X POST http://localhost:9377/tabs/abc123/navigate \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "url": "https://example.com"}'
```

Or use a search macro:

```bash
curl -X POST http://localhost:9377/tabs/abc123/navigate \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "macro": "@google_search", "query": "weather today"}'
```

### 4. Get Snapshot (accessibility tree with refs)

```bash
curl "http://localhost:9377/tabs/abc123/snapshot?userId=agent1"
```

Returns element refs like `[link e1]`, `[button e2]` for interaction.

### 5. Interact

```bash
# Click by ref
curl -X POST http://localhost:9377/tabs/abc123/click \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "ref": "e1"}'

# Type text
curl -X POST http://localhost:9377/tabs/abc123/type \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "ref": "e2", "text": "hello", "pressEnter": true}'

# Scroll
curl -X POST http://localhost:9377/tabs/abc123/scroll \
  -H "Content-Type: application/json" \
  -d '{"userId": "agent1", "direction": "down", "amount": 500}'
```

### 6. Screenshot

```bash
curl "http://localhost:9377/tabs/abc123/screenshot?userId=agent1"
```

Returns base64-encoded PNG.

### 7. Close Tab

```bash
curl -X DELETE "http://localhost:9377/tabs/abc123?userId=agent1"
```

## Search Macros

| Macro | Site |
|-------|------|
| `@google_search` | Google |
| `@youtube_search` | YouTube |
| `@amazon_search` | Amazon |
| `@reddit_search` | Reddit |
| `@wikipedia_search` | Wikipedia |
| `@twitter_search` | Twitter/X |
| `@yelp_search` | Yelp |
| `@linkedin_search` | LinkedIn |

## Session Management

- `userId` isolates cookies/storage between users
- `sessionKey` groups tabs by conversation/task
- Sessions timeout after 30 minutes of inactivity (configurable)
- Destroy all user data: `DELETE /sessions/:userId`

## Common Pitfalls

1. **Node.js not in PATH** — On Nix-based systems (Replit), Node lives at `/nix/store/.../bin/node`. Use the full path or export PATH before running npm/node commands.
2. **Replit npm proxy 404s** — The local proxy (`package-firewall.replit.local`) blocks many packages. Always use `--registry=https://registry.npmjs.org`.
3. **Missing fontconfig/ symlink** — Bundle has `fontconfigs/` (plural) but camoufox-js checks for `fontconfig/` (singular). Create: `ln -sfn /path/to/bundle/fontconfigs /path/to/bundle/fontconfig`
4. **version.json format mismatch** — The browser bundle's version.json uses `"build"` but camoufox-js expects `"release"`. Fix: rewrite with a `"release"` field (e.g. `"release":"135.0.1-beta.24"`).
5. **camoufox-js MAX_VERSION too low** — Versions <0.11.x ship with `MAX_VERSION = "1"` which rejects browser v135+. Patch `node_modules/camoufox-js/dist/__version__.js`: change to `"999"`.
6. **better-sqlite3 native binding missing** — Using `--ignore-scripts` skips native builds. Rebuild with: `npm rebuild better-sqlite3` (ensure Node is in PATH).
7. **No virtual display (headless env)** — Camoufox needs X11. In a headless Replit container, Xvfb is unavailable and the server cannot launch the browser. Use REST APIs that don't require browser interaction, or run on a machine with a display.
8. **--ignore-scripts required** — Post-install scripts that fetch binaries will fail on Replit. Always use `--ignore-scripts` for npm install.
9. **Port conflict** — Default is 9377. Change with `CAMOFOX_PORT` if occupied.

## Verification Checklist

- [ ] Server responds at `GET /health` with `{"ok":true}`
- [ ] Can create a tab with `POST /tabs`
- [ ] Can navigate and get a snapshot with element refs
- [ ] Can take a screenshot
- [ ] Can close the tab

## Reference

- Source: https://github.com/jo-inc/camofox-browser
- Full API spec: `GET /openapi.json` (served by the running server)
- Docs UI: `GET /docs` (swagger-stripey interface)
- `references/replit-headless-setup.md` — step-by-step Replit/Nix setup with all errors encountered and fixes
