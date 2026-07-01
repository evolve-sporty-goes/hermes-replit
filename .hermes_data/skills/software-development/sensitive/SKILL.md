---
name: sensitive
description: "Scan workspace for files containing secrets, tokens, API keys, and credentials. Update .gitignore sensitive block automatically. Sync script reads from .gitignore with auto-remediation for GitHub push protection blocks."
version: 3.0.0
author: Hermes Agent
tags: [security, secrets, credentials, gitignore]
---

# Sensitive File Finder

Scan all files and folders within the user's active workspace for secrets, tokens, API keys, passwords, and credentials. Update the sensitive-files block in `.gitignore` automatically.

**Architecture note:** The sync script (`scripts/sync`) reads sensitive file paths directly from `.gitignore`'s sensitive block — NOT from `sensitive.txt`. `.gitignore` entries use bare names or relative paths (e.g. `credentials/.pat`, `brave-browser/`, `freellmapi`). The sync script resolves these against the workspace root and expands directories to individual files.

## Trigger Conditions

- User asks to find sensitive files, tokens, secrets, or credentials
- User asks to update `.gitignore` sensitive block
- User runs the `/sensitive` slash command (if configured)

## Workflow

### 1. Scan Workspace

Run a comprehensive scan across the entire workspace (excluding `.git/`, `.cache/`, `.local/`, `.pythonlibs/`, `.config/`, and similar system directories):

**Primary: gitleaks (recommended)**
```bash
# Install gitleaks if not present
curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.21.0/gitleaks_8.21.0_linux_x64.tar.gz | tar -xz -C ~/.local/bin/ gitleaks
chmod +x ~/.local/bin/gitleaks

# Scan entire repo (history + working dir)
gitleaks detect --source /home/runner/workspace --verbose

# Scan working directory only (no history)
gitleaks detect --source /home/runner/workspace --no-git

# Scan specific files/dirs
gitleaks detect --source /home/runner/workspace/path/to/file
```

**Fallback: grep patterns (if gitleaks unavailable)**
```bash
# Find files matching common secret patterns by name
find /home/runner/workspace \
  -not -path '*/.git/*' \
  -not -path '*/.cache/*' \
  -not -path '*/.local/*' \
  -not -path '*/.pythonlibs/*' \
  -not -path '*/.config/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/.hermes_data/webui/*' \
  -type f \
  \( -name '*secret*' -o -name '*credential*' -o -name '*token*' -o \
     -name '*api_key*' -o -name '*apikey*' -o -name '*password*' -o \
     -name '*auth*' -o -name '*key*' -o -name '*.pem' -o \
     -name '*.env' -o -name '.env*' -o -name '*_key*' -o \
     -name '*_secret*' -o -name '*_token*' -o \
     -name 'config.py' -o -name '*.bat' -o -name '*.cmd' \) 2>/dev/null

# Scan file contents for secret patterns (API keys, tokens, high-entropy strings)
grep -rIl -E '(AKIA|ghp_|gho_|xoxb-|xoxp-|sk-|AIza|Bearer|eyJhb|api_key|apikey|password\s*=|secret\s*=|token\s*=)' \
  /home/runner/workspace \
  --exclude-dir=.git \
  --exclude-dir=.cache \
  --exclude-dir=.local \
  --exclude-dir=.pythonlibs \
  --exclude-dir=.config \
  --exclude-dir=node_modules \
  --exclude-dir=.hermes_data/webui \
  --exclude-dir=.hermes_data/skills \
  2>/dev/null
```

Also scan for files containing base64-encoded strings, private keys, and Supabase anon keys:

```bash
grep -rIl -E '(-----BEGIN |supabase|eyJ[A-Za-z0-9_-]{50,})' \
  /home/runner/workspace \
  --exclude-dir=.git \
  --exclude-dir=.cache \
  --exclude-dir=.local \
  --exclude-dir=.pythonlibs \
  --exclude-dir=.config \
  --exclude-dir=node_modules \
  --exclude-dir=.hermes_data/webui \
  --exclude-dir=.hermes_data/skills \
  2>/dev/null
```

### 2. Cross-Reference .gitignore Sensitive Section

The sync script reads from `.gitignore`'s sensitive block (lines starting after `# Sensitive files` comment). Every entry that exists on disk must be covered. Files may be gitignored without being detected by content scanning (e.g. `scripts/email.sh`, `freellmapi`, `.hermes_data/webui/sessions/`).

```bash
# Extract non-comment, non-blank entries from .gitignore sensitive section
grep -A 100 '# Sensitive' /home/runner/workspace/.gitignore | grep -v '^#' | grep -v '^$'
```

For each entry: resolve to absolute path (prepend workspace root if relative), verify it exists on disk (`[ -e "$path" ]`), and add to the candidate list if not already present. Skip entries that no longer exist (historical .gitignore entries for removed files/directories).

### 3. Deduplicate and Filter

- Remove duplicates from combined results
- Exclude system/framework files that contain placeholder/example values
- Exclude documentation files (.md) that reference secrets as examples
- Include `.sh`, `.py`, `.txt`, `.env*`, `.json`, `.yaml`, `.yml`, `.toml`, and config files
- **Always include** `.hermes_data/webui/sessions/` — session logs capture full conversation content including secrets mentioned in chat

### 4. Update .gitignore Sensitive Block

Replace the sensitive-files section in `.gitignore`:

```gitignore
# Sensitive files (auto-managed by sensitive skill — do not edit)
# Synced to hermes-secrets repo via sync.sh
credentials/.pat
credentials/.supabase_anon_key
credentials/openrouter_credentials.txt
credentials/firecrawl_credentials.txt
credentials/torbox_credentials.txt
credentials/cloudflare.txt
scripts/email.sh
.hermes_data/.env
.hermes_data/auth.json
.hermes_data/state.db
brave-browser/
freellmapi
.hermes_data/webui/sessions/
.hermes_data/config.yaml
```

Rules:
- Use **relative paths** from workspace root (e.g. `credentials/.pat` not `/home/runner/workspace/credentials/.pat`)
- Use **bare directory names** with trailing slash for directories (e.g. `brave-browser/`, `.hermes_data/webui/sessions/`)
- The sync script resolves these against the workspace root and expands directories to individual files
- Keep existing whitelist rules (`!.gitignore`, `!.replit`, `!.hermes_data/`)
- Preserve the `*env`, `*shm`, `*wal` patterns
- Comment the section clearly with `# Sensitive files` header

### 5. Verify

Run verification:
```bash
echo "=== .gitignore sensitive section ==="
sed -n '/^# Sensitive/,/^[^#]/p' /home/runner/workspace/.gitignore
echo "=== Verify all .gitignore sensitive entries exist on disk ==="
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  [[ "$entry" =~ ^# ]] && continue
  # Strip trailing slash for directory check
  clean="${entry%/}"
  path="/home/runner/workspace/$clean"
  [ -e "$path" ] && echo "OK  $entry" || echo "MISSING: $entry"
done < <(sed -n '/^# Sensitive/,/^[^#]/p' /home/runner/workspace/.gitignore | grep -v '^#' | grep -v '^$')
```

## Pitfalls

- Do NOT scan `.git/` directory
- Do NOT accidentally expose secret content in output — only file paths
- `config.py` in `$HOME` (created by `email.sh`) contains credentials — include it if present
- Bash scripts often contain hardcoded keys in `curl` commands — check `.sh` files carefully
- **`.gitignore` uses relative paths** — the sync script resolves them against workspace root. Always use relative paths (e.g. `credentials/.pat`) not absolute (`/home/runner/workspace/credentials/.pat`)
- **Directories in `.gitignore`** — use trailing slash (e.g. `brave-browser/`, `.hermes_data/webui/sessions/`). The sync script expands these to individual files at depth 1
- Exclude `.hermes_data/skills/` — those are agent skills, not secrets
- Exclude `.hermes_data/memories/`, `.hermes_data/logs/`, `.hermes_data/obsidian-vault/`, `.hermes_data/lsp/` — not secrets
- Exclude session dumps (`request_dump*.json`, `*.jsonl`, `_run_journal/`, `_turn_journal/`)
- Exclude `.hermes_history`, `.hermes_data/.hermes_history` — conversation history
- Exclude docs (`.md`) that just reference secret patterns in examples
- `freellmapi` — check contents; if it contains literal API keys or tokens, include it (it is not a secret by name alone, but in practice it often stores credential data)
- Exclude `*.log`, `*.lock`, `*_check`, `auth.json.corrupt`
- **`.hermes_data/config.yaml`** — Hermes config may contain API keys set via `hermes config set`. Include in sensitive block if it contains literal credentials (cloudflare.apiKey, etc.)
- **`.hermes_data/webui/sessions/`** — session logs capture ALL conversation content including secrets mentioned in chat. Always include the directory in `.gitignore` sensitive block
- **gitleaks vs betterleaks** — betterleaks (github.com/betterleaks/betterleaks) is a faster, modern Rust rewrite with built-in validation. Use `betterleaks git --source .` for repo scan, `betterleaks git --source . --staged` for pre-commit. Both support gitleaks config (`.gitleaks.toml` / `.betterleaks.toml`)

## Handling Already-Tracked Files

When removing a file from `.gitignore` (user wants it tracked), `git add` will fail if the file was previously gitignored. Use `git add -f <path>` to force-stage it. Verify with `git check-ignore <path>` — exit code 1 means NOT ignored (tracked as desired).

## grep False Positives

Scripts like `torbox-*.sh` may reference API URLs (e.g., `https://db.torbox.app/auth/v1/signup`) that match `api_key` or `token` patterns in grep. These are NOT secrets — they're API endpoints. Filter them out by checking if the match is a literal credential value vs a URL or variable reference.

## Verification: Use Relative Paths for git check-ignore

`git check-ignore` works with relative paths from the repo root. Using absolute paths may give wrong results. Always run from the workspace root with relative paths:
```bash
cd /home/runner/workspace && git check-ignore credentials/.pat
```

## User Preference: mail.txt Tracking

The user explicitly wants `credentials/mail.txt` to remain tracked in git (not ignored). When updating `.gitignore`, do NOT include `mail.txt` unless the user explicitly asks. If a file was previously gitignored and the user wants it tracked, use `git add -f` to force-stage it.

## Sync Script Design (v3 — 2026-06-29 rewrite)

The sync script (`scripts/sync`) was rewritten from scratch to be short (~90 lines), reliable, and fast. Key design decisions:

- **No AI commit messages** — single descriptive commit per run listing changed files. Eliminates API latency (8-10s per file) and JSON parse failures.
- **No `set -e`** — aborts on loop EOF and non-critical failures. Uses `||` for explicit error handling.
- **Single askpass** for both phases — secrets sync and workspace push share one `GIT_ASKPASS` script, cleaned up via EXIT trap.
- **No per-file commits** — workspace changes are one commit: `auto: 2026-06-29T11:39:31Z — 3 file(s): foo bar baz`
- **No auto filter-repo** — history rewrite is a manual, explicit operation, not baked into the sync loop.

### Sync Script Output Format

```
[11:39:26] ═══ PHASE 1: secrets ═══
  OK credentials/.pat
  PUSH → .hermes_data/state.db (newer)
  SKIP brave-browser
  PULL ← .hermes_data/config.yaml (newer)
[11:39:27] OK: secrets pushed
[11:39:27] ═══ PHASE 2: workspace ═══
[11:39:31] OK: workspace pushed
[11:39:31] ═══ SYNC DONE ═══
```

Format: `ACTION →/← relative/path (reason)`

### Bash Pitfalls Learned During Rewrite

1. **`set -e` + `while read` EOF** — `read` returns 1 at EOF; with `set -e` this kills the script even though the loop completed normally. Use `set -uo pipefail` (drop `-e`) and handle errors explicitly with `||`.

2. **Function definition order** — Bash does NOT hoist functions. Define `_sync_one` BEFORE the `while` loop that calls it.

3. **Subshell function return values** — `func && s=$? || s=$?` is fragile. Use `func || changed=1` for flag-setting patterns.

4. **Trap RETURN from functions** — `trap "cleanup" RETURN` inside a function fires when the function returns, which can clean up resources still needed by the caller. Use a single EXIT trap in main scope instead.

5. **Askpass lifecycle** — If Phase 1 creates an askpass in a function with RETURN-trap cleanup, it's gone before Phase 2's push. Create askpass once at script scope, clean up in EXIT trap.

6. **`find ... -print0 | while read -r -d ''`** — when find matches nothing, the while body never runs but the overall pipeline exits 0. Safe to use. But combined with `set -e` and a `local` declaration inside the loop body, can cause issues — keep loop bodies simple.

See `references/sync-gitignore-integration.md` for how `scripts/sync` reads `.gitignore` and resolves bare directory/file names to full paths.
See `references/sync-commit-message-ai.md` for the rationale behind removing AI commit messages.
See `references/sync-bash-pitfalls.md` for bash scripting pitfalls learned during the v3 rewrite.
See `references/push-protection-history-rewrite.md` for the manual history-rewrite workflow (no longer auto-triggered).
