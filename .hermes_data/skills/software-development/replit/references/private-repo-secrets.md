# Private Repo Secrets Pattern

Store sensitive config (`.env`, `.pat` tokens, credentials, API keys) in a dedicated private GitHub repo, separate from the main project repo. Pull it at deploy/entrypoint time. Supports bidirectional sync when the workspace can also modify secrets.

## When to Use

- User wants secrets backed up to GitHub but not committed to the main repo
- git-crypt / SOPS feel like overkill
- You already have a working push path to GitHub from the environment

## Architecture

```
hermes-replit (public)          hermes-secrets (private)
├── .gitignore (*env, *.pat)    ├── .env
├── sync-secrets.sh             ├── .pat
├── .replit                     └── README.md
└── ...
```

The sync script handles both directions (bidirectional). For pull-only setups, a simpler `pull-secrets.sh` is sufficient.

## Setup

### 1. Create the private repo

```bash
gh repo create hermes-secrets --private --clone=false
```

### 2. Push secrets to it (one-time, from an environment with auth)

```bash
# From a machine with working GitHub auth:
cd /path/to/hermes-secrets
cp /home/runner/workspace/.hermes_data/.env .
git add .env
git commit -m "chore: add .env from hermes_data"
git push
```

If pushing from Replit (where HTTPS push is blocked), use the credential helper pattern:

```bash
# Extract token from gh config (if gh is authenticated)
TOKEN=$(grep 'oauth_token:' ~/.config/gh/hosts.yml | tail -1 | awk '{print $2}')
printf 'https://oauth2:%s@github.com\n' "$TOKEN" > /tmp/.git_creds_$$
git config credential.helper store --file=/tmp/.git_creds_$$
git push origin main
rm -f /tmp/.git_creds_$$
git config --unset credential.helper
```

### 3. Create the pull script

`pull-secrets.sh` (token-based — works on Replit):

```bash
#!/bin/bash
# Pull .env from the hermes-secrets private repo
# Usage: ./pull-secrets.sh [GITHUB_TOKEN]  or  GITHUB_TOKEN=*** ./pull-secrets.sh

set -euo pipefail

TOKEN="${1:-${GITHUB_TOKEN:-}}"
SECRETS_REPO="https://github.com/<owner>/hermes-secrets.git"

if [ -z "$TOKEN" ]; then
    echo "ERROR: No token. Pass as argument or set GITHUB_TOKEN env var."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Askpass helper for git (bypasses replit-git-askpass)
ASKPASS="$TMPDIR/git-askpass"
echo "#!/bin/bash" > "$ASKPASS"
echo "echo '$TOKEN'" >> "$ASKPASS"
chmod +x "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"

if git clone --depth 1 --branch main "$SECRETS_REPO" "$TMPDIR/hermes-secrets" 2>/dev/null; then
    cp "$TMPDIR/hermes-secrets/.env" /home/runner/workspace/.hermes_data/.env
    echo "OK: .env pulled to .hermes_data/.env"
else
    echo "ERROR: Failed to clone secrets repo"
    exit 1
fi
```

Alternative (idempotent — reuses clone across restarts):

```bash
#!/usr/bin/env bash
set -euo pipefail
TOKEN="${1:-${GITHUB_TOKEN:-}}"
SECRETS_DIR="/tmp/hermes-secrets"
SECRETS_REPO="https://github.com/<owner>/hermes-secrets.git"

if [ -z "$TOKEN" ]; then
    echo "ERROR: No token."
    exit 1
fi

ASKPASS=$(mktemp /tmp/git-askpass-XXXXXX)
echo "#!/bin/bash" > "$ASKPASS"
echo "echo '$TOKEN'" >> "$ASKPASS"
chmod +x "$ASKPASS"

if [ -d "$SECRETS_DIR/.git" ]; then
    GIT_ASKPASS="$ASKPASS" git -C "$SECRETS_DIR" pull --ff-only 2>/dev/null
else
    GIT_ASKPASS="$ASKPASS" git clone --depth 1 --branch main "$SECRETS_REPO" "$SECRETS_DIR" 2>/dev/null
fi

rm -f "$ASKPASS"
cp "$SECRETS_DIR/.env" /home/runner/workspace/.hermes_data/.env
echo "OK: .env synced"
```

### 4. Wire into `.replit` entrypoint

```toml
entrypoint = "bash pull-secrets.sh"
run = "bash start.sh"
```

## Security Properties

- `.env` never appears in the public repo's git history
- The private repo is only as secure as the GitHub account's 2FA
- The pull script uses a shallow clone (`--depth 1`) to minimize disk/tokens
- The clone lives in `/tmp` (ephemeral on Replit) — `.env` is copied to the workspace

## Pitfall: Auth for the pull script

The pull script itself needs auth to clone the private repo. On Replit, this means:

- If using HTTPS: the pull script needs a credential helper or token (same problem as push)
- If using SSH: works if SSH keys are configured in the container
- Alternative: use Replit Secrets to store `GITHUB_TOKEN`, then:

```bash
# In pull-secrets.sh, before git clone:
git config credential.helper store --file=/tmp/.git_creds_$$
printf 'https://oauth2:%s@github.com\n' "$GITHUB_TOKEN" > /tmp/.git_creds_$$
# ... clone ...
rm -f /tmp/.git_creds_$$
```

## Bidirectional Sync Pattern (2026-06-25)

When the workspace can both consume and produce changes to secrets (e.g. `.env` edited locally, `.pat` rotated), a single sync script handles both directions each run. This replaces the one-way pull-only script.

### `sync-secrets.sh` — pull if remote is ahead, push if local differs

```bash
#!/bin/bash
# Sync .env and .pat with hermes-secrets private repo
# Detects divergence and pulls/pushes automatically
# Usage: GITHUB_TOKEN=*** ./sync-secrets.sh  or  ./sync-secrets.sh <token>

set -euo pipefail

TOKEN="${1:-${GITHUB_TOKEN:-}}"
SECRETS_REPO="https://github.com/<owner>/hermes-secrets.git"
LOCAL_ENV="/home/runner/workspace/.hermes_data/.env"
LOCAL_PAT="/home/runner/workspace/.pat"

if [ -z "$TOKEN" ]; then
    echo "ERROR: No token. Pass as argument or set GITHUB_TOKEN env var."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Askpass helper
ASKPASS="$TMPDIR/git-askpass"
echo "#!/bin/bash" > "$ASKPASS"
echo "echo '$TOKEN'" >> "$ASKPASS"
chmod +x "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"

# Clone secrets repo
if ! git clone --depth 1 --branch main "$SECRETS_REPO" "$TMPDIR/secrets" 2>/dev/null; then
    echo "ERROR: Failed to clone secrets repo"
    exit 1
fi

cd "$TMPDIR/secrets"

# --- PULL: if remote has newer commits, pull ---
LOCAL_HEAD="$(git rev-parse HEAD 2>/dev/null || echo '')"
git fetch --unshallow origin main 2>/dev/null || true
git checkout main 2>/dev/null || true
REMOTE_HEAD="$(git rev-parse origin/main 2>/dev/null || echo '')"

if [ -n "$REMOTE_HEAD" ] && [ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]; then
    echo "Remote is ahead — pulling..."
    git pull origin main 2>/dev/null || true
    for f in .env .pat; do
        if [ -f "$TMPDIR/secrets/$f" ]; then
            if [ "$f" = ".env" ]; then
                cp "$TMPDIR/secrets/$f" "$LOCAL_ENV"
                echo "OK: pulled .env"
            else
                cp "$TMPDIR/secrets/$f" "$LOCAL_PAT"
                echo "OK: pulled .pat"
            fi
        fi
    done
fi

# --- PUSH: if local has changes, push ---
git config user.email "hermes@replit"
git config user.name "hermes-replit"

changed=0
if [ -f "$LOCAL_ENV" ] && ! diff -q "$LOCAL_ENV" "$TMPDIR/secrets/.env" >/dev/null 2>&1; then
    cp "$LOCAL_ENV" "$TMPDIR/secrets/.env"
    git add .env
    changed=1
fi
if [ -f "$LOCAL_PAT" ] && ! diff -q "$LOCAL_PAT" "$TMPDIR/secrets/.pat" >/dev/null 2>&1; then
    cp "$LOCAL_PAT" "$TMPDIR/secrets/.pat"
    git add .pat
    changed=1
fi

if [ "$changed" -eq 1 ]; then
    git commit -m "auto: update secrets from hermes-replit $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if git push origin main 2>/dev/null; then
        echo "OK: pushed changes to secrets repo"
    else
        echo "WARN: push failed (will retry next run)"
    fi
else
    echo "OK: no local changes to push"
fi
```

### How it works

1. Clone secrets repo (shallow) into `/tmp`
2. `fetch --unshallow` to get full history for comparison
3. Compare `LOCAL_HEAD` vs `REMOTE_HEAD` — if remote ahead, pull and copy files to workspace
4. Use `diff -q` to compare local `.env`/`.pat` against what's in the secrets repo — if local differs, copy into secrets repo, commit, push
5. Idempotent: if nothing changed in a direction, that direction is skipped

### Usage in a cron / loop

```bash
# Every 5 minutes, sync secrets
*/5 * * * * cd /home/runner/workspace && GITHUB_TOKEN=*** ./sync-secrets.sh >> /tmp/sync-secrets.log 2>&1
```

Or as a long-running watcher:

```bash
while true; do
    GITHUB_TOKEN=*** ./sync-secrets.sh
    sleep 300
done
```

### Pitfalls

- **`fetch --unshallow` cost**: First run after a shallow clone fetches full history. Subsequent runs with `--depth 1` clones are cheap because the remote ref hasn't changed (no fetch needed unless remote is ahead).
- **Race conditions**: If both sides change simultaneously, pull happens first, then push. The push may fail if the remote moved again — retry on next loop iteration.
- **Token in process list**: `echo '$TOKEN'` in the askpass helper is visible in `ps` briefly. Acceptable for most cases; for higher security, use `GIT_ASKPASS` pointing to a file with the token read at runtime.

## Comparison with Alternatives

| Approach | Complexity | History | Team-friendly |
|----------|-----------|---------|---------------|
| Private repo (this) | Low | Clean (secrets never in main repo) | Medium (clone per dev) |
| git-crypt | Medium | Encrypted in history | High (key share) |
| SOPS | High | Encrypted in history | High (per-key access) |
| GitHub Secrets (CI) | Low | Clean | Low (Actions only) |
