---
name: hermes-cli-automation
trigger: "non-interactive hermes, scripted hermes setup, hermes config set, custom endpoint script, hermes model automation, CI hermes, hermes without prompts, replit hermes, replit startup, replit workflow, hermes auto-restart, hermes crash recovery"
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

### Single-File Credential Pool (User Choice)

The user's final choice: **one file** holding all credential pairs. Pairs are consecutive lines (line 1+2, 3+4, …) selected by stepping through the file two lines at a time:

**File layout:**
```
credentials/cloudflare.txt
```

Content — alternating lines (`ACCOUNT_ID` then `API_KEY`, no blank lines between pairs):
```ini
ACCOUNT_ID=d70ba859348c4d2da672ff5874f91b84
API_KEY=3x-0NXXgbQIY_zh5BTM0d0VH14BrUy2uH2TSL9aPWq-Ut67PQBcItRkoa_X
ACCOUNT_ID=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
API_KEY=cfut_RANDSAMPLEKEY00000000000000000000000000000
```

**Why the user chose single-file over per-file pool:**
- One file is faster to edit than creating a new `.txt` per account
- Glob ordering concerns go away
- Simpler mental model

**Parsing pattern (place pairs by stepping +2 lines, NOT random byte offsets):**
```bash
mapfile -t LINES < <(grep -v '^[[:space:]]*$' "$CRED")
PAIRS=()
for ((i=0; i<${#LINES[@]}; i+=2)); do
  A=$(echo "${LINES[$i]}" | cut -d= -f2)
  K=$(echo "${LINES[$((i+1))]}" | cut -d= -f2)
  PAIRS+=("$A:$K")
done
SEL="${PAIRS[$((RANDOM % ${#PAIRS[@]}))]}"
ACCOUNT_ID="${SEL%%:*}"
API_KEY="${SEL##*:}"
```

**Critical:** Always pair positions are known-indexed (line N + line N+1), never random selection from two separate sources. The user corrected this after a flawed parallel-array approach risked cross-matching wrong account/key pairs.

See `references/cloudflare-single-file-pool.sh` for a complete template.

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
- Credentials in **service-specific files**, never hardcoded inline in chat.
- User dislikes **numbered variable patterns** (e.g. `ACCOUNT_ID_1`, `ACCOUNT_ID_2`) — prefer pools with auto-detected size.
- User prefers **one file per service** holding all credential pairs (not one file per account).
- For the single-file pool: pairs are consecutive lines (line 1+2, 3+4, …) selected by stepping through two lines at a time. Adding new entries = append two lines (`account_id`/`api_key`).
- Keep scripts **short** (<30 lines), single-flow, no flags/options/menus/helper functions.
- Cloudflare `account_id` is the key input — script asks for it (not the full URL), then builds `https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1`.

## Pitfalls

- **`${2:?...}` mangling**: the `?` error-message operator inside `${...}` can get mangled when a script body is passed through `write_file` or terminal layers. **Always save the script to a file first** (via `write_file`), `chmod +x`, then run with positional args.
- **Python inline in shell on NixOS**: `API_KEY=*** -c "...")` can break due to shell quoting in the terminal tool. Use `execute_code` (Python block) to generate secrets, then pass to the script.
- **`model.api_compat openai`** = "Chat Completions" API mode. Other compat modes may exist per Hermes version.
- `hermes config set` writes to `~/.hermes/config.yaml` — no `hermes` restart needed for the config to take effect on next session start.
- **Parallel array pattern**: when using `ACCOUNT_IDS=(...)` + `API_KEYS=(...)`, ensure both arrays stay in sync (same length, same position = same credential pair). Prefer file-based pools to avoid this entirely.
- **Credential pairing integrity**: when reading pairs from a single file, always select by known position (line N paired with line N+1), never by random index into two separate arrays — that risks cross-matching wrong account/key pairs.
- **`hermes config set` writes to `~/.hermes/config.yaml** — no `hermes` restart needed for the config to take effect on next session start.
- **Do not verify config from `config.yaml` directly**: always verify the active model via `hermes config show` — this reads the live resolved config Hermes will actually use. User explicitly corrected this.
- **Glob pitfall**: `*$((RANDOM % N))` needs double `$((...))` arithmetic expansion. Single-layer `${POOL[RANDOM % N]}` is a syntax error in bash.
- **`printf` format string mangling**: when writing scripts via `write_file`, the `%s` placeholders in `printf` format strings can get dropped or mangled by terminal/shell escaping layers. Always verify the written file with `bash -n` after creation. If broken, use `patch` to fix the specific line.
- **Cloudflare URL convention**: endpoint format is `https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1`. Script should ask for `account_id` (not full URL) and construct the endpoint internally.
- **Fallback models are managed at top level, not nested**: set `fallback_model.provider` and `fallback_model.model` via `hermes config set`, not under `custom_providers`. Verify with `hermes fallback list`.
- **`hermes fallback add` is interactive** and reuses the same TUI picker as `hermes model`; in non-interactive contexts use direct `hermes config set fallback_model.*` commands instead.

## state.db Corruption Repair

When `hermes sessions repair` and `hermes doctor --fix` both fail with:
- `btreeInitPage() returns error code 11`
- `database disk image is malformed`
- `state.db fails a write-health probe`

The FTS full-text index pages are corrupt but the main data tables (sessions, messages, state_meta) are usually still readable. Recovery:

Use `references/state-db-corruption-repair.py` — it connects via Python `sqlite3` (bypasses damaged page cache), copies schema + data from all non-FTS tables into a fresh `state.db.new`, drops broken FTS tables (Hermes rebuilds them on next session indexing), then swaps it in.

Hermes sessions are gated behind `hermes doctor --fix` success. Hermes itself won't start a new session with a corrupted FTS index.

**Why this matters**: FTS corruption is not data loss. The sessions/messages/state_meta tables live on different b-tree pages than the FTS index. Corrupt FTS pages block `hermes doctor` from passing while your conversation history remains intact on healthy pages.

## Replit Workflow with Auto-Restart

On Replit, the `.replit` config controls workflows and startup behavior. To run Hermes on startup with crash recovery:

### 1. Create a startup wrapper script

`scripts/hermes-startup.sh` — wraps Hermes with:
- Auto-restart on non-zero exit (crash recovery)
- Rate limiting: max N restarts per time window (prevents infinite crash loops)
- Single-instance guard via PID file
- Structured logging to `logs/hermes-startup.log`
- All install/setup phases (uv, repo clone, venv, PATH, wrapper creation, background services)

See `references/replit-startup-wrapper.sh` for a complete template.

### 2. Update `.replit` config

```toml
[workflows]
runButton = "Project"

[startup]
startOn = "Project"

[[workflows.workflow]]
name = "Hermes"
mode = "parallel"

[[workflows.workflow.tasks]]
task = "shell.exec"
args = "bash ~/workspace/scripts/hermes-startup.sh"

[[workflows.workflow]]
name = "Project"
mode = "parallel"

[[workflows.workflow.tasks]]
task = "workflow.run"
args = "Hermes"
```

Key points:
- `[startup] startOn = "Project"` tells Replit to auto-run on container start
- The "Hermes" workflow runs the startup wrapper; "Project" workflow triggers it via `workflow.run`
- Use `mode = "parallel"` so the workflow doesn't block the Replit UI
- The wrapper handles install + launch + restart in one script — Replit only needs to call it once

### Restart rate-limiting strategy

Track restart timestamps in an array, count those within a sliding window (e.g. 5 min). If count exceeds threshold (e.g. 10), stop and log "manual intervention required" — prevents infinite crash loops from a persistent error (bad config, missing dep, etc.).

Exit code 0 = clean user quit → no restart. Any other code → restart after delay.

## Reference

- `references/cloudflare-ai-setup.sh` — single-account script template
- `references/cloudflare-ai-pool.sh` — parallel-array pool script template
- `references/cloudflare-file-pool.sh` — file-based credential pool (one file per account)
- `references/cloudflare-single-file-pool.sh` — single file holding all credential pairs (user's final choice)
- `references/state-db-corruption-repair.py` — recover from FTS b-tree page corruption when `hermes sessions repair` fails
- `references/replit-startup-wrapper.sh` — Replit startup wrapper with auto-restart and rate limiting
