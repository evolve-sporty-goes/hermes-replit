---
name: github-auth
description: "GitHub auth setup: HTTPS tokens, SSH keys, gh CLI login."
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Authentication, Git, gh-cli, SSH, Setup]
    related_skills: [github-pr-workflow, github-code-review, github-issues, github-repo-management]
---

# GitHub Authentication Setup

This skill sets up authentication so the agent can work with GitHub repositories, PRs, issues, and CI. It covers two paths:

- **`git` (always available)** — uses HTTPS personal access tokens or SSH keys
- **`gh` CLI (if installed)** — richer GitHub API access with a simpler auth flow

## Detection Flow

When a user asks you to work with GitHub, run this check first:

```bash
# Check what's available
git --version
gh --version 2>/dev/null || echo "gh not installed"

# Check if already authenticated
gh auth status 2>/dev/null || echo "gh not authenticated"
git config --global credential.helper 2>/dev/null || echo "no git credential helper"
```

**Decision tree:**
1. If `gh auth status` shows authenticated → you're good, use `gh` for everything
2. If `gh` is installed but not authenticated → use "gh auth" method below
3. If `gh` is not installed → use "git-only" method below (no sudo needed)

---

## Method 1: Git-Only Authentication (No gh, No sudo)

This works on any machine with `git` installed. No root access needed.

### Option A: HTTPS with Personal Access Token (Recommended)

This is the most portable method — works everywhere, no SSH config needed.

**Step 1: Create a personal access token**

Tell the user to go to: **https://github.com/settings/tokens**

- Click "Generate new token (classic)"
- Give it a name like "hermes-agent"
- Select scopes:
  - `repo` (full repository access — read, write, push, PRs)
  - `workflow` (trigger and manage GitHub Actions)
  - `read:org` (if working with organization repos)
- Set expiration (90 days is a good default)
- Copy the token — it won't be shown again

**Step 2: Configure git to store the token**

```bash
# Set up the credential helper to cache credentials
# "store" saves to ~/.git-credentials in plaintext (simple, persistent)
git config --global credential.helper store

# Now do a test operation that triggers auth — git will prompt for credentials
# Username: <their-github-username>
# Password: <paste the personal access token, NOT their GitHub password>
git ls-remote https://github.com/<their-username>/<any-repo>.git
```

After entering credentials once, they're saved and reused for all future operations.

**Alternative: cache helper (credentials expire from memory)**

```bash
# Cache in memory for 8 hours (28800 seconds) instead of saving to disk
git config --global credential.helper 'cache --timeout=28800'
```

**Alternative: set the token directly in the remote URL (per-repo)**

```bash
# Embed token in the remote URL (avoids credential prompts entirely)
git remote set-url origin https://<username>:<token>@github.com/<owner>/<repo>.git
```

**Step 3: Configure git identity**

```bash
# Required for commits — set name and email
git config --global user.name "Their Name"
git config --global user.email "their-email@example.com"
```

**Step 4: Verify**

```bash
# Test push access (this should work without any prompts now)
git ls-remote https://github.com/<their-username>/<any-repo>.git

# Verify identity
git config --global user.name
git config --global user.email
```

### Option B: SSH Key Authentication

Good for users who prefer SSH or already have keys set up.

**Step 1: Check for existing SSH keys**

```bash
ls -la ~/.ssh/id_*.pub 2>/dev/null || echo "No SSH keys found"
```

**Step 2: Generate a key if needed**

```bash
# Generate an ed25519 key (modern, secure, fast)
ssh-keygen -t ed25519 -C "their-email@example.com" -f ~/.ssh/id_ed25519 -N ""

# Display the public key for them to add to GitHub
cat ~/.ssh/id_ed25519.pub
```

Tell the user to add the public key at: **https://github.com/settings/keys**
- Click "New SSH key"
- Paste the public key content
- Give it a title like "hermes-agent-<machine-name>"

**Step 3: Test the connection**

```bash
ssh -T git@github.com
# Expected: "Hi <username>! You've successfully authenticated..."
```

**Step 4: Configure git to use SSH for GitHub**

```bash
# Rewrite HTTPS GitHub URLs to SSH automatically
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

**Step 5: Configure git identity**

```bash
git config --global user.name "Their Name"
git config --global user.email "their-email@example.com"
```

---

## Method 2: gh CLI Authentication

If `gh` is installed, it handles both API access and git credentials in one step.

### Interactive Browser Login (Desktop)

```bash
gh auth login
# Select: GitHub.com
# Select: HTTPS
# Authenticate via browser
```

### Token-Based Login (Headless / SSH Servers)

```bash
echo "<THEIR_TOKEN>" | gh auth login --with-token

# Set up git credentials through gh
gh auth setup-git
```

### Verify

```bash
gh auth status
```

---

## Using the GitHub API Without gh

When `gh` is not available, you can still access the full GitHub API using `curl` with a personal access token. This is how the other GitHub skills implement their fallbacks.

### Setting the Token for API Calls

```bash
# Option 1: Export as env var (preferred — keeps it out of commands)
export GITHUB_TOKEN="<token>"

# Then use in curl calls:
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user
```

### Extracting the Token from Git Credentials

If git credentials are already configured (via credential.helper store), the token can be extracted:

```bash
# Read from git credential store
grep "github.com" ~/.git-credentials 2>/dev/null | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|'
```

### Helper: Detect Auth Method

Use this pattern at the start of any GitHub workflow:

```bash
# Try gh first, fall back to git + curl
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  echo "AUTH_METHOD=gh"
elif [ -n "$GITHUB_TOKEN" ]; then
  echo "AUTH_METHOD=curl"
elif _hermes_env="${HERMES_HOME:-$HOME/.hermes}/.env"; [ -f "$_hermes_env" ] && grep -q "^GITHUB_TOKEN=" "$_hermes_env"; then
  export GITHUB_TOKEN=$(grep "^GITHUB_TOKEN=" "$_hermes_env" | head -1 | cut -d= -f2 | tr -d '\n\r')
  echo "AUTH_METHOD=curl"
elif grep -q "github.com" ~/.git-credentials 2>/dev/null; then
  export GITHUB_TOKEN=$(grep "github.com" ~/.git-credentials | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|')
  echo "AUTH_METHOD=curl"
else
  echo "AUTH_METHOD=none"
  echo "Need to set up authentication first"
fi
```

---

## Migrating from HTTPS Token to SSH (Recommended Long-Term)

When a user's push fails because of a rejected or expired PAT, and they want to switch to SSH:

**Step 1: Generate an SSH key (if none exists)**

```bash
# Check for existing keys first
ls ~/.ssh/id_*.pub 2>/dev/null || echo "No SSH keys found"

# Generate ed25519 key (no passphrase for agent use)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "their-email@example.com" -f ~/.ssh/id_ed25519 -N ""
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Show the public key
cat ~/.ssh/id_ed25519.pub
```

**Step 2: User adds the public key to GitHub**

Tell the user to go to: **https://github.com/settings/keys**
- Click "New SSH key"
- Paste the public key
- Title: `hermes-agent-<machine-name>`

**Step 3: Trust GitHub's host key**

Before pushing, the local machine must trust GitHub's host key, or git will fail with `Host key verification failed`:

```bash
# Scan and trust GitHub's host key
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
```

**Step 4: Switch the remote URL from HTTPS to SSH**

```bash
# Check current remote
git remote -v

# Switch to SSH
git remote set-url origin git@github.com:<owner>/<repo>.git

# Configure git to use SSH for all GitHub URLs (optional but recommended)
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

**Step 5: Verify**

```bash
# Test SSH connection
ssh -T git@github.com
# Expected: "Hi <username>! You've successfully authenticated..."

# Test push
git push
```

**Step 5: Security cleanup**

If the old PAT was embedded in the remote URL or stored in `~/.git-credentials`, remove it:

```bash
# Remove token from credential store
git credential reject <<EOF
protocol=https
host=github.com
EOF

# Verify no token remains in remote URL
git remote -v
# Should show git@github.com:..., NOT https://user:token@github.com/...
```

## Security note: If a user pastes a live PAT into chat (e.g. to fix a push failure), remind them immediately that the token is now in their terminal history and our conversation. They should **revoke it on GitHub and generate a new one**. Never store or reuse a token the user shared this way.

## Token File Pattern (.pat)

Some users store tokens in a `.pat` file at the repo root. This is a simple alternative to Replit Secrets or credential helpers:

```bash
# .pat file contains raw token: ghp_xxxxx
TOKEN=*** /home/runner/workspace/.pat | tr -d '\n')
```

The pull-secrets script and push-via-askpass pattern both accept this token as an argument or env var. The `.pat` file should be in `.gitignore` (or matched by a `*pat` / `*token` rule) to avoid accidental commit.

---

## Troubleshooting

For push-specific auth failures (non-github.com remotes, expired tokens, PAT vs SSH resolution), see `references/push-auth-failure.md`. For a complete step-by-step migration walkthrough with real error messages, see `references/ssh-migration-recipe.md`. For extracting tokens from `gh` config or private-repo secrets patterns, see `references/github-config-token-extraction.md`.

| Problem | Solution |
|---------|----------|
| `git push` asks for password | GitHub disabled password auth. Use a personal access token as the password, or switch to SSH |
| `remote: Permission to X denied` | Token may lack `repo` scope — regenerate with correct scopes |
| `fatal: Authentication failed` | Cached credentials may be stale — run `git credential reject` then re-authenticate |
| `remote: Invalid username or token. Password authentication is not supported` | Token is missing, expired, or wrong. Two fixes: (1) set a PAT in the remote URL: `git remote set-url origin https://<user>:<token>@<host>/<owner>/<repo>.git` then retry, or (2) switch to SSH: `git remote set-url origin git@<host>:<owner>/<repo>.git` (requires SSH key at https://<host>/settings/keys) |
| `ssh: connect to host github.com port 22: Connection refused` | Try SSH over HTTPS port: add `Host github.com` with `Port 443` and `Hostname ssh.github.com` to `~/.ssh/config` |
| `Host key verification failed` | Trust GitHub's host key first: `ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null` |
| Credentials not persisting | Check `git config --global credential.helper` — must be `store` or `cache` |
| Multiple GitHub accounts | Use SSH with different keys per host alias in `~/.ssh/config`, or per-repo credential URLs |
| `gh: command not found` + no sudo | Use git-only Method 1 above — no installation needed |
| `error: unable to read askpass response from 'replit-git-askpass'` | Replit environment with no HTTPS credentials. `replit-git-askpass` intercepts ALL credential prompts. Check `echo $REPLIT_ASKPASS_PID2_SESSION` — if empty, askpass cannot fetch tokens. Options: (1) use Replit Secrets tab for `GITHUB_TOKEN` then `printf 'https://oauth2:%s@github.com\\n' "$GITHUB_TOKEN" > /tmp/.git_creds && git config credential.helper store --file=/tmp/.git_creds && git push && rm -f /tmp/.git_creds && git config --unset credential.helper`, (2) switch to SSH, (3) push from local machine, (4) **`.pat` file + credential store** (cleanest for Replit): store PAT in `.pat` at repo root (gitignored), then push via: `TOKEN=$(cat /home/runner/workspace/.pat | tr -d '\\n') && printf "https://oauth2:${TOKEN}@github.com\\n" > /tmp/git-creds.txt && git config credential.helper "store --file=/tmp/git-creds.txt" && git push origin main && rm -f /tmp/git-creds.txt && git config --unset credential.helper`. Note: `/tmp/` wipes on Replit restarts — regenerate creds file at session start if push fails. The `.pat` file must never be committed — verify with `git status` before bulk commits. |
| `gh` installed but not authenticated, need token for git push | Extract the OAuth token from `gh`'s config file: `TOKEN=$(grep 'oauth_token:' ~/.config/gh/hosts.yml | tail -1 | awk '{print $2}')`. Use it with credential helper: `printf 'https://oauth2:%s@github.com\\n' "$TOKEN" > /tmp/.git_creds_$$ && git config credential.helper store --file=/tmp/.git_creds_$$ && git push && rm -f /tmp/.git_creds_$$ && git config --unset credential.helper`. Note: `gh auth status` may still report "invalid" for stale config even when the token works for git. Verify token validity independently with `curl -s -H "Authorization: bearer $TOKEN" https://api.github.com/user`. |
| `fatal: The current branch main has no upstream branch` | First push for a branch. Use `git push -u origin main` or `git push --set-upstream origin main` |
