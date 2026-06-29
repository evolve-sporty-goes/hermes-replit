---
name: hermes-cli-automation
trigger: "non-interactive hermes, scripted hermes setup, hermes config set, custom endpoint script, hermes model automation, CI hermes, hermes without prompts"
description: "Automate Hermes Agent CLI configuration non-interactively — model selection, custom endpoints, credentials, and config editing via `hermes config set` instead of interactive wizards. Covers scripted setups, CI, Docker, and ephemeral environments."
version: 1
---

# Hermes CLI Automation

The `hermes model` and `hermes setup` commands are interactive (prompt_toolkit wizards). For scripts, CI, Docker, ephemeral environments, or any non-interactive context, use `hermes config set` to write config values directly.

## When to Use

- Setting up Hermes in a script or Dockerfile
- Configuring a custom endpoint without the interactive picker
- Automating model/provider switches in CI pipelines
- Ephemeral environments (Replit, Modal, Daytona) where interactivity is unavailable

## Core Pattern: `hermes config set`

```bash
hermes config set <section>.<key> <value>
```

Writes directly to `~/.hermes/config.yaml` (or `$HERMES_HOME/config.yaml`). No restart needed.

## Custom Endpoint (OpenAI-compatible)

Maps each interactive `hermes model` step to a config command:

| Interactive step | Command |
|---|---|
| Select "custom endpoint" | `hermes config set model.provider custom` |
| Enter base URL | `hermes config set model.base_url <url>` |
| Enter API key | `hermes config set model.api_key <key>` |
| Select API compat mode (e.g. "Chat Completions") | `hermes config set model.api_compat openai` |
| Enter model name | `hermes config set model.default <model_id>` |
| Enter display name | `hermes config set model.display_name <name>` |

### Cloudflare AI Script

See `references/cloudflare-ai-setup.sh` for a ready-to-use template:

```bash
#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <cloudflare_account_id> <api_key>}"
API_KEY=*** $0 <cloudflare_account_id> <api_key>}"

hermes config set model.provider custom
hermes config set model.base_url "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai          # "Chat Completions" mode
hermes config set model.default "@cf/<model>"       # e.g. @cf/moonshotai/kimi-k2.7-code
hermes config set model.display_name "cloudflare"
```

Set on Replit: copy to `scripts/setup_cloudflare.sh`, run `bash scripts/setup_cloudflare.sh <id> <key>`.

### Generic OpenAI-compatible Script

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:?base_url}"
API_KEY=*** api_key}"
MODEL="${3:?model_name}"

hermes config set model.provider custom
hermes config set model.base_url "${BASE_URL}"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai
hermes config set model.default "${MODEL}"
```

## Agent Preferences

- User prefers **file-based scripts** over inline commands. Write to disk first, then `chmod +x` and run.
- User wants **terse commands only, no preamble** — "tell me commands i will execute."
- Credentials in **service-specific .txt files** or positional args, never hardcoded inline in chat.

## Pitfalls

- **`${2:?...}` mangling in heredoc**: the `?` error-message operator inside `${...}` can get mangled when a script body is passed through terminal evaluation layers or echo/cat heredocs. **Always save the script to a file first** (via `write_file`), `chmod +x`, then run with positional args.
- **Python inline in shell on NixOS**: `API_KEY=*** -c "...")` can break due to shell quoting in the terminal tool. Use `execute_code` (Python block) to generate secrets, then pass to the script.
- **`model.api_compat openai`** = "Chat Completions" API mode. Other compat modes may exist per Hermes version.
- `hermes config set` writes to `~/.hermes/config.yaml` — no `hermes` restart needed for the config to take effect on next session start.

## Reference

- `references/cloudflare-ai-setup.sh` — reusable script template for Cloudflare AI custom endpoint setup
