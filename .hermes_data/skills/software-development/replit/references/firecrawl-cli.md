# Firecrawl CLI on Replit

## Installation

Firecrawl CLI is an npm global package. It may or may not be pre-installed depending on the Replit image.

### Check if installed
```
which firecrawl
# Expected: /home/runner/workspace/.config/npm/node_global/bin/firecrawl
```

If the path does not exist, install:
```
npm install -g firecrawl-cli
```

Or use directly via npx without installing:
```
npx firecrawl <command>
```

### Verify version and auth
```
firecrawl --version
firecrawl --status
```
`--status` shows auth state + remaining credits — use it as the canonical "is it working?" check after install and login.

## Authentication

The API key lives in `.hermes_data/.env` (not the repo root `.env`). Source it before passing to firecrawl:

```bash
source /home/runner/workspace/.hermes_data/.env
firecrawl login --api-key "$FIRECRAWL_API_KEY"
```

Or set the env var globally in `.replit` config:
```toml
[nix]
channel = "stable-24_05"
packages = ["firecrawl-cli"]
```

Then in `run`:
```toml
run = "source .hermes_data/.env && firecrawl --status"
```

## Common Commands

| Command | Use |
|---------|-----|
| `firecrawl scrape <url>` | Scrape URL, saves to `.firecrawl/` |
| `firecrawl crawl <url>` | Crawl entire site |
| `firecrawl search <query>` | Search the web |
| `firecrawl --status` | Check auth + credits |
| `firecrawl doctor` | Environment diagnostics |

## Pitfalls

- **Tool output sanitizer masks `$VAR`**: Hermes replaces `$VAR` with `***` in displayed output. The actual file on disk is correct. Verify with `python3 -c "print(open('/home/runner/workspace/.hermes_data/.env').read()[:200])"` if you suspect a missing variable.
- **`.env` vs `.hermes_data/.env`**: The repo root `.env` may be empty or contain non-secret values. Secrets (including `FIRECRAWL_API_KEY`) are in `.hermes_data/.env`.
- **No `pip install firecrawl` needed for CLI**: The CLI is an npm package (`firecrawl-cli`), not a Python package. Use `npm install -g firecrawl-cli` or `npx firecrawl`.
- **CLI not present on fresh Replit images**: Despite earlier docs claiming it was always pre-installed, some Replit Nix images ship without it. Always run `which firecrawl` first — if empty, `npm install -g firecrawl-cli` before attempting `firecrawl login`.
- **`npm install -g` works without Nix**: Unlike many system packages on Replit (which require `[nix]` config), `npm install -g` runs inside the persistent `.config/npm/node_global` directory in `~/workspace`, so it survives deploys.
