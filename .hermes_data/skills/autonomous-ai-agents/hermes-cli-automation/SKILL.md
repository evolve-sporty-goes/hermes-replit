---
name: hermes-cli-automation
trigger: "non-interactive hermes, scripted hermes setup, hermes config set, custom endpoint script, hermes model automation, CI hermes, hermes without prompts"
description: "Automate Hermes Agent CLI configuration non-interactively — model selection, custom endpoints, credential pooling/rotation, and config editing via `hermes config set` instead of interactive wizards. Covers scripted setups, CI, Docker, and ephemeral environments."
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

See `references/cloudflare-ai-setup.sh` for a ready-to-use template. For randomized credential pooling (rotate across N accounts), see `references/cloudflare-ai-pool.sh`.

### Single-Account Script

```bash
#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <cloudflare_account_id> [display_name]}"
API_KEY=*** $0 <cloudflare_account_id> [display_name]}"
DISPLAY_NAME="${3:-cloudflare}"

hermes config set model.provider custom
hermes config set model.base_url "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai          # "Chat Completions" mode
hermes config set model.default "@cf/<model>"       # e.g. @cf/moonshotai/kimi-k2.7-code
hermes config set model.display_name "${DISPLAY_NAME}"
```

Set on Replit: copy to `scripts/setup_cloudflare.sh`, run `bash scripts/setup_cloudflare.sh <id> <key>`.

### File-Based Credential Pool (Recommended)

Store credentials as individual `.txt` files in a `credentials/` directory — one file per account. The script globs the directory, so adding a new account is just creating a file (no script edits, no numbering, no risk of arrays going out of sync):

**File layout:**
```
credentials/
├── cloudflare_001.txt
├── cloudflare_002.txt
└── cloudflare_003.txt
```

Each file:
```
ACCOUNT_ID=<id>
API_KEY=***
```

**Script pattern:**
```bash
#!/usr/bin/env bash
set -euo pipefail

CRED_DIR="${WORKSPACE:-$HOME/workspace}/credentials"
POOL=("$CRED_DIR"/cloudflare_*.txt)
((${#POOL[@]})) || { echo "No credentials found"; exit 1; }

CRED="${POOL[$((RANDOM % ${#POOL[@]}))]}"
ACCOUNT_ID=$(awk -F= '/^ACCOUNT_ID/{print $2}' "$CRED")
API_KEY=*** '/^API_KEY/{print $2}' "$CRED")
BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"

hermes config set model.provider custom
hermes config set model.base_url "${BASE_URL}"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"
```

**Why this beats parallel arrays:**
- Adding/removing accounts = create/delete a `.txt` file (zero script edits)
- No risk of arrays going out of sync (each credential is self-contained)
- No numbering to maintain — pool via glob
- Credentials live outside the script, can be gitignored independently

See `references/cloudflare-file-pool.sh` for a complete template.

### Credential Pool / Random Selection (Parallel Arrays)

For environments that need automatic credential rotation across N accounts, use parallel arrays indexed by `RANDOM % N`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_IDS=(
  "id_1"
  "id_2"
  "id_3"
  "id_4"
  "id_5"
)
API_KEYS=(
  "key_1"
  "key_2"
  "key_3"
  "key_4"
  "key_5"
)

IDX=$(( RANDOM % ${#ACCOUNT_IDS[@]} ))
ACCOUNT_ID="${ACCOUNT_IDS[$IDX]}"
API_KEY="${API_KEYS[$IDX]}"

echo "[$IDX] Selected account: ${ACCOUNT_ID:0:8}..."

hermes config set model.provider custom
hermes config set model.base_url "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"
```

Add your real Cloudflare account IDs and API keys to the arrays. Replace entries 1–N with your actual credentials.

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
- User wants **terse commands only, no preamble**.
- Credentials in **service-specific .txt files** or positional args, never hardcoded inline in chat.
- User dislikes **numbered variable patterns** (e.g. `ACCOUNT_ID_1`, `ACCOUNT_ID_2`) — prefer file-based or unnumbered array pools.
- Keep scripts **short** (<50 lines), single-flow, no flags/options/menus/helper functions.

## Pitfalls

- **`${2:?...}` mangling**: the `?` error-message operator inside `${...}` can get mangled when a script body is passed through `write_file` or terminal layers. **Always save the script to a file first** (via `write_file`), `chmod +x`, then run with positional args.
- **Python inline in shell on NixOS**: `API_KEY=*** -c "...")` can break due to shell quoting in the terminal tool. Use `execute_code` (Python block) to generate secrets, then pass to the script.
- **`model.api_compat openai`** = "Chat Completions" API mode. Other compat modes may exist per Hermes version.
- `hermes config set` writes to `~/.hermes/config.yaml` — no `hermes` restart needed for the config to take effect on next session start.
- **Parallel array pattern**: when using `ACCOUNT_IDS=(...)` + `API_KEYS=(...)`, ensure both arrays stay in sync (same length, same position = same credential pair). Prefer file-based pools to avoid this entirely.
- **Do not verify config from `config.yaml` directly**: always verify the active model via `hermes config show` — this reads the live resolved config Hermes will actually use.
- **`hermes model` is interactive-only**: fails in non-interactive shells with "requires an interactive terminal". Use `hermes config set` for all scripted configuration.
- **File-based pool glob ordering**: `"$CRED_DIR"/cloudflare_*.txt` returns files in lexicographic order. Names like `cloudflare_001.txt` sort predictably; avoid names that sort inconsistently (e.g. `cloudflare_1.txt` vs `cloudflare_10.txt`).

## state.db Corruption Repair

When `hermes sessions repair` and `hermes doctor --fix` both fail with:
- `btreeInitPage() returns error code 11`
- `database disk image is malformed`
- `state.db fails a write-health probe`

The FTS full-text index pages are corrupt but the main data tables (sessions, messages, state_meta) are usually still readable. Recovery pattern:

1. Connect via Python `sqlite3` (bypasses damaged page cache)
2. Copy schema + data from all non-FTS tables
3. Build a fresh state.db
4. Drop the broken FTS tables — they get recreated on next session indexing

See `references/state-db-corruption-repair.sh` for the full repair script.

**Why this matters**: FTS corruption is not data loss. The sessions, messages, messages_fts, and state_meta tables live on different b-tree pages. Corrupt FTS pages block `hermes doctor` from passing while all your conversation history remains intact on healthy pages.

## Reference

- `references/cloudflare-ai-setup.sh` — single-account script template
- `references/cloudflare-ai-pool.sh` — parallel-array pool script template
- `references/cloudflare-file-pool.sh` — file-based credential pool (recommended)
- `references/state-db-corruption-repair.sh` — recover from FTS b-tree page corruption
