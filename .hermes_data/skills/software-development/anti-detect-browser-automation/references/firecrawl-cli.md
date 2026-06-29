# Firecrawl CLI Reference

## Installation

```bash
npm install -g firecrawl-cli@1.19.6
```

## Authentication

### Via environment variable
```bash
export FIRECRAWL_API_KEY=fc-xxxxxxxx
```

### Via CLI login
```bash
firecrawl login --api-key "fc-xxxxxxxx"
```

Credentials stored securely by the CLI after login.

### Keyless free tier
Search, scrape, and interact still work without an API key on the
keyless free tier (rate-limited). Browser login or an API key is
preferred for best results.

## Verification

```bash
firecrawl --version    # 1.19.6
firecrawl --status     # Shows auth state, credits, concurrency
```

## Common commands

```bash
# Scrape a URL to markdown
firecrawl scrape "https://example.com" -o output.md

# Search the web
firecrawl search "query"

# Crawl a site
firecrawl crawl "https://example.com" -o results/
```

## API key location

In this workspace, the key is stored in `.hermes_data/.env` as
`FIRECRAWL_API_KEY`. Source it before using the CLI:

```bash
source /home/runner/workspace/.hermes_data/.env
firecrawl login --api-key "$FIRECRAWL_API_KEY"
```
