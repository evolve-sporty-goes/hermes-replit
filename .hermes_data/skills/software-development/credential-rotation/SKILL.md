---
name: credential-rotation
description: Proactive API key rotation patterns — check quota before use, rotate at threshold, multi-key failover. Covers OpenRouter, Anthropic, OpenAI, and generic OAuth providers.
category: software-development
---

# Credential Rotation Patterns

## Core Principle

**Rotate BEFORE quota exhaustion** — query provider's auth/quota endpoint, calculate usage %, switch keys at configurable threshold (default 80%). Never hit 429/402.

## OpenRouter Rotation (Proactive)

### Minimal Script Structure

```bash
#!/usr/bin/env bash
# or-rotate "prompt" [model] [threshold_pct]

KEYS_FILE="$HOME/.config/openrouter/keys.txt"
STATE_FILE="$HOME/.config/openrouter/state.json"
MODEL="${2:-nvidia/nemotron-3-ultra-550b-a55b:free}"
THRESHOLD="${3:-80}"

mapfile -t KEYS < "$KEYS_FILE"
IDX=$(jq -r '.idx // 0' "$STATE_FILE")

for i in $(seq 0 $((${#KEYS[@]}-1))); do
  TRY=$(( (IDX + i) % ${#KEYS[@]} ))
  KEY="${KEYS[$TRY]}"
  
  # Check quota via /auth/key
  read -r USAGE LIMIT <<<"$(curl -s -H "Authorization: Bearer $KEY" \
    https://openrouter.ai/api/v1/auth/key | jq -r '.data | "\(.usage) \(.limit)"')"
  
  [[ -z "$USAGE" || "$LIMIT" == "0" ]] && continue
  PCT=$(( USAGE * 100 / LIMIT ))
  (( PCT < THRESHOLD )) && break
done

# Use selected key for request...
```

### Key Files

| File | Purpose |
|------|---------|
| `~/.config/openrouter/keys.txt` | One key per line (never in repo) |
| `~/.config/openrouter/state.json` | `{ "idx": 3 }` — rotation position |
| `scripts/or-rotate` | Executable rotation script |

### Usage

```bash
# Default 80% threshold
or-rotate "Explain quantum computing"

# Custom model + 60% threshold
or-rotate "Write code" "anthropic/claude-3.5-sonnet" 60
```

## Reading Keys from Credentials File

When keys live in a structured credentials file (e.g., `workspace/credentials/openrouter_credentials.txt`):

```bash
mapfile -t KEYS < <(grep -o 'sk-or-[^ ]*' "$CREDS_FILE")
```

### Usage Check (Random Audit)

For a fast spot-check without modifying state, pick one random usable key from a credentials file and query `/api/v1/auth/key`:

```bash
awk -F= '/^API_KEY=/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$CREDS_FILE" | grep -v NOT_FOUND | shuf -n 1 | while read -r API_KEY; do
  curl -sS -H "Authorization: Bearer ${API_KEY}" https://openrouter.ai/api/v1/auth/key | python3 -m json.tool
done
```

See `scripts/or_check_usage.sh` for a hardened standalone version.

## User Preferences (Embedded)

- **Terse bash only** — no preamble, no markdown, no explanations in scripts
- **Background silent setup + foreground spinner** — all output to log file, single-line spinner on stdout
- **Save to `workspace/scripts/`, `chmod +x`**
- **Iterative scripts** — counter → spinner → production
- **File-based creds** — `~/config.py`, `workspace/credentials/`
- **Unredacted output** — show full keys, tokens, URLs in results

## Pitfalls

1. **Don't read `.env` directly** — Hermes blocks direct reads of credential files. Use provider's auth endpoint instead.
2. **Each key = separate account** — rotation changes account, not just key. Memories/context don't transfer.
3. **Threshold too high = 429 risk** — 80% is safe default; 60% for critical workloads.
4. **State file corruption** — always use `jq` for atomic writes, never `echo`.

## Related Patterns

- **Betterleaks integration** — scan for leaked keys pre-commit, auto-gitignore (see `references/betterleaks-gitignore.md`)
- **Multi-provider rotation** — same pattern works for Anthropic (`/v1/organizations`), OpenAI (`/v1/usage`), etc.
- **Cron job rotation** — schedule proactive rotation checks independent of request traffic

## Support Files

| File | Description |
|------|-------------|
| `scripts/or_rotate_min.sh` | Minimal rotation reading from `credentials/openrouter_credentials.txt` |
| `scripts/or-rotate-proactive.sh` | Full proactive rotation with config file at `~/.config/openrouter/keys.txt` |
| `scripts/betterleaks-gitignore.sh` | One-liner scan + auto-gitignore |
| `scripts/or_check_usage.sh` | Random-key usage audit against OpenRouter `/api/v1/auth/key` without rotation state changes; prints `KEY=...` then a single `usage` number |
| `references/betterleaks-gitignore.md` | BetterLeaks patterns, installation, pre-commit hook |