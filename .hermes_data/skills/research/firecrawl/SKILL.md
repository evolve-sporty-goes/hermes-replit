---
name: firecrawl
description: "Firecrawl CLI for web search and scraping — preferred over SDK in constrained environments."
version: 1.0.0
author: Hermes Agent + jhajikv-mute
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [web, search, scraping, firecrawl, cli]
    category: research
    related_skills: []
---

# Firecrawl CLI

Search and scrape the web via the `firecrawl` npm CLI. Preferred over the Python SDK in constrained environments (Replit, sandboxes) because the CLI is self-contained and avoids local shadow conflicts.

## When to Use

- Web search from environments where `web_search` is unavailable or rate-limited
- Scraping URLs to markdown for research, data extraction, or archival
- When the user explicitly prefers CLI tools over SDKs

## Prerequisites

```bash
# Install Node.js (Replit Nix — no node by default)
nix-env -iA nixpkgs.nodejs_20
# Or on systems with apt:
# sudo apt install nodejs npm

# Install firecrawl CLI globally
# NOTE: `firecrawl` (SDK-only, no CLI binary). The CLI is in `firecrawl-cli`.
npm install -g firecrawl-cli

# Authenticate (requires https://firecrawl.dev API key)
firecrawl login --api-key $FIRECRAWL_API_KEY
```

Free tier: 1000 credits/month.

## Quick Reference

```bash
# Search
firecrawl search "query"                    # web search
firecrawl search "query" --limit 5          # limit results

# Scrape single URL → markdown
firecrawl scrape "https://example.com"      # markdown output to stdout

# Scrape with options
firecrawl scrape "https://example.com" --formats markdown --onlyMainContent
```

## Procedure

1. Verify `firecrawl` is available: `which firecrawl` or `firecrawl --version`
2. If not available, install via `npm install -g firecrawl-cli` (requires Node.js)
3. If not authenticated, run `firecrawl login --api-key $FIRECRAWL_API_KEY`
4. Run the desired command and capture stdout
5. For large outputs, redirect to a file: `firecrawl scrape <URL> > /tmp/output.md`

## Pitfalls

- **SDK vs CLI package**: The `firecrawl` npm package is SDK-only (Python/JS library, no CLI binary). The actual CLI is `firecrawl-cli`. Installing `firecrawl` will NOT give you the `firecrawl` command. Always use `npm install -g firecrawl-cli`.
- **No Node.js on Replit Nix**: `node`/`npm` are not pre-installed. Use `nix-env -iA nixpkgs.nodejs_20` or configure `.replit` to auto-install. Do NOT try `sudo apt` — no sudo on NixOS.
- **Local `firecrawl.py` shadow**: If a local file named `firecrawl.py` exists in cwd, Python imports it before the npm CLI. Fix: remove/rename the local file, then `npm install -g firecrawl-cli`.
- **API key in chat**: User provides credentials manually (e.g. via `.env` or `$FIRECRAWL_API_KEY`). Never inline API keys in commands visible in chat.
- **SDK vs CLI**: Prefer `firecrawl` CLI commands over `from firecrawl import FirecrawlApp` in constrained environments. The SDK is fine when the CLI isn't available or when you need advanced async/job management.
- **Output size**: Scraped pages can be very large. Use `--onlyMainContent` to reduce noise, or redirect to file for post-processing.

## Verification

```bash
which firecrawl && firecrawl --version
firecrawl search "test query" --limit 1
```
