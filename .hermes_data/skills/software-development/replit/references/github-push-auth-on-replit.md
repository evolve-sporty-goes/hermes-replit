# GitHub Push Authentication on Replit

## The Problem

Replit injects a custom `replit-git-askpass` credential helper that intercepts all git credential prompts. This means:

- `git push https://github.com/...` works interactively ONLY if `replit-git-askpass` has credentials
- No PAT, no interactive prompt, no push
- `GIT_ASKPASS` env var — DOES override `replit-git-askpass` when set to an executable script that echoes the token. Earlier docs claimed it was always intercepted — **this is incorrect**.
- Per-remote credential helpers (`url.<base>.insteadOf`) are also intercepted

## Error Patterns

```
error: unable to read askpass response from 'replit-git-askpass'
fatal: could not read Username for 'https://github.com': No such device or address
```
→ `replit-git-askpass` is present and has no credentials to return.

```
remote: Invalid username or token. Password authentication is not supported for Git operations.
```
→ A token was provided (e.g. via URL or token file) but it's expired, revoked, or has wrong scopes.

## Why Common Workarounds Fail on Replit

| Approach | Why it fails |
|----------|--------------|
| `GIT_ASKPASS=/path/to/script` (simple echo) | Works — the script must be executable and echo the full token. Earlier docs claimed this is always intercepted — **incorrect**. |
| `git config credential.helper store --file=/path` | `replit-git-askpass` takes precedence |
| `gh auth login --with-token` | Works for CLI push, but initial auth still requires a valid token |
| Gist-based token | Token may be expired; also leaks token in URL for anyone with access |
| Token in remote URL (`https://user:token@...`) | Works but token persists in `.git/config` (recoverable forever) |

## Root Cause: Why Askpass Fails

`replit-git-askpass` is a Nix store binary that intercepts ALL git credential prompts. It requires the `REPLIT_ASKPASS_PID2_SESSION` env var to be set so it can fetch a token from Replit's pid2 service (port 8284 inside the container). In many Replit shell contexts this env var is empty, so askpass exits 1 and git reports:

```
error: unable to read askpass response from 'replit-git-askpass'
fatal: could not read Username for 'https://github.com': No such device or address
```

Setting `GIT_ASKPASS` DOES override it — git's askpass mechanism fires when no credential helper has an answer, and a properly set `GIT_ASKPASS` (executable script echoing the token) takes precedence.

### Diagnosing the askpass env var

Check whether the pid2 session is active:

```bash
echo "REPLIT_ASKPASS_PID2_SESSION=${REPLIT_ASKPASS_PID2_SESSION:-EMPTY}"
```

If this prints `EMPTY`, the askpass script cannot fetch tokens and HTTPS push will fail. This env var is only set inside the Replit shell (the Replit IDE terminal), NOT in generic background terminals or cron jobs. There is no way to set it manually — it comes from the Replit runtime.

### Inspecting the askpass script itself

The askpass binary is a symlink into the Nix store:

```
/nix/store/...-replit-runtime-path/bin/replit-git-askpass
  → /nix/store/...-replit-git-askpass/bin/replit-git-askpass
```

Key behavior in the script:
- If `REPLIT_ASKPASS_PID2_SESSION` is empty or "0" → exits 1 immediately
- For GitHub prompts: echoes a hardcoded username, then fetches token from `localhost:8284/<session>/github/token`
- For password prompts: fetches token from the same pid2 endpoint
- If curl fails or token is empty → prints "Unable to connect your GitHub account" and exits 1

This means: **even if you have a valid GitHub account connected in Replit, HTTPS push still fails outside the Replit shell** because the pid2 session endpoint is unreachable.

### Caveat: `git://` remotes are a workaround, not a solution

A plain `git://` remote (e.g. a VPS bare repo) needs no auth and pushes work from anywhere. But:
- `git://` is unencrypted — anyone on the network can read and write
- It's a separate backup host, NOT a replacement for GitHub
- Removing it after setting up real auth is the right call (`git remote remove <name>`)
- Do NOT leave mystery remotes in the user's repo — always explain what they are
- When a user asks "what is this remote?", explain the full URL breakdown (protocol, host, port, path) — don't just say "it's a backup"

### Session example: user discovered and removed a `git://` remote

The user had a remote `gitsafe-backup` pointing to `git://gitsafe:5418/backup.git`. It worked for push (no auth) but was confusing and served no purpose once we confirmed GitHub push was blocked by askpass. We removed it. Lesson: if you push to a `git://` remote as a stopgap, tell the user explicitly what it is and that it should be removed when real auth is set up.

## Working Options (Ranked)

### 0b. Inline token in push URL (simplest one-shot, confirmed working 2026-06)

When you have a PAT in `.pat` and just need to push without any interactive setup, embed the token directly in the push URL:

```bash
TOKEN=$(cat .pat | tr -d '\n')
git push "https://oauth2:${TOKEN}@github.com/<owner>/<repo>.git" main
```

Works without `GIT_ASKPASS`, without `credential.helper store`, without SSH setup. No tokens written to `.git/config`, no credential files left on disk.

**Caveat:** Token appears in the process list momentarily. For shared machines that's an exposure — prefer option 01 (credential store) for those cases.

### 0. Use a plain (non-HTTPS) remote (zero-auth backup, not GitHub)

If you have a secondary remote using `git://` (no auth needed for push), use it as a stopgap or mirror:

```bash
git remote add backup git://host:port/repo.git  # one-time setup
git push backup main
```

Works immediately with no tokens, no SSH keys, no secrets. The remote is NOT GitHub — it's a separate backup host. Use this only while setting up real GitHub auth. Remove it when done (`git remote remove backup`).

Caveat: `git://` is unencrypted. Don't use it for repos with sensitive content. Don't add mystery remotes to the user's repo without explaining what they are.

### 1. Replit Secrets (Recommended — persistent, no token handling)

Replit Secrets are injected as env vars at runtime. This is the only non-interactive, non-leaking path:

1. Open the Replit "Secrets" panel (padlock icon in sidebar)
2. Add a secret: `GITHUB_TOKEN` = `ghp_xxxxx` (classic PAT with `repo` scope)
3. In any script, use it:

```bash
git config credential.helper store --file=/tmp/.git_creds_$$
printf 'https://oauth2:%s@github.com\n' "$GITHUB_TOKEN" > /tmp/.git_creds_$$
# push succeeds because git credential helper > replit-git-askpass during write
git push
rm -f /tmp/.git_creds_$$
```

Note: `credential.helper store` **does** work for the push operation itself — the askpass only triggers when `store` has no match. Writing to the store first avoids askpass.

### 2. SSH with a deploy key (no interactivity, revocable)

If you don't want PATs at all:

```bash
git remote set-url origin git@github.com:<owner>/<repo>.git
```
Then add an ed25519 public key to https://github.com/settings/keys. The key lives in the Replit container's `~/.ssh/`.

Caveat: Replit containers may not persist `~/.ssh/` across redeploys unless the key is injected (e.g. via Secrets file mount or Nix config).

### 3. `gh` CLI (if pre-authenticated)

If `gh auth status` shows authenticated in the Replit environment, `git push` delegates to `gh`-managed credentials and works transparently.

## Decision Matrix

| Situation | Use |
|-----------|-----|
| You have a `git://` remote (e.g. gitsafe-backup) | Option 0 — push there immediately, zero auth needed |
| You control the Replit secrets | Replit Secrets (option 1) — zero token exposure |
| You can add SSH key to GitHub | SSH deploy key (option 2) — survives container restarts if key is in persistent storage |
| `gh` is already logged in | `gh`-managed (option 3) — works out of the box |
| You only need local pushes | Push from your own machine; remove the watcher from install.sh |

## Pattern: Push when local has diverged from origin

When `git status` shows "Your branch and 'origin/main' have diverged, and have N and M different commits each":

```bash
# 1. Stash uncommitted work
git stash

# 2. Rebase local commits on top of remote
git pull origin main --rebase

# 3. Resolve conflicts (common in .hermes_data/logs/)
#    Log files are operational noise — safe to accept 'ours' (the rebased version)
git checkout --ours .hermes_data/logs/agent.log .hermes_data/logs/errors.log
git add .hermes_data/logs/agent.log .hermes_data/logs/errors.log
git rebase --continue

# 4. Restore stashed work
git stash pop
#    If stash pop conflicts on log files again:
git checkout --ours .hermes_data/logs/agent.log .hermes_data/logs/errors.log

# 5. Push
TOKEN=*** .pat") && \
  ASKPASS=$(mktemp) && \
  printf '#!/bin/bash\necho %s\n' "$TOKEN" > "$ASKPASS" && \
  chmod +x "$ASKPASS" && \
  GIT_ASKPASS="$ASKPASS" git push origin main && \
  rm -f "$ASKPASS"
```

Key insight: `.hermes_data/logs/agent.log` and `errors.log` accumulate high-volume operational output. Conflicts during rebase on these files are safe to resolve with `--ours` because they'll be regenerated immediately. Never manually merge log file conflicts — always take one side.

An auto-push watcher (`sleep && git add && git commit && git push`) will fail silently or loop forever if the container has no auth. Always wrap `git push` so failure doesn't lose the commit:

```bash
if git commit -m "auto: update"; then
    git push && last=$(date +%s)  # only advance cooldown if push succeeds
fi
```

If auth is not configured in the container, remove the watcher entirely and push from a machine that has auth.

## Pattern: Bootstrap Push Token via .pat file + Credential Store

When the user stores their PAT in a `.pat` file at the repo root (gitignored), push non-interactively:

```bash
TOKEN=*** /home/runner/workspace/.pat | tr -d '\n')
printf "https://oauth2:${TOKEN}@github.com\n" > /tmp/git-creds.txt
git config credential.helper "store --file=/tmp/git-creds.txt"
git push origin main
rc=$?
rm -f /tmp/git-creds.txt
git config --unset credential.helper 2>/dev/null
exit $rc
```

Advantages over gist-based approach:
- Token is local — no network fetch needed
- No gist URL to expire or leak
- `.pat` can be synced with hermes-secrets repo via sync-secrets.sh
- `/tmp/` wipes on Replit restarts — regenerate creds file at session start if push fails

See also the gist-based variant and pitfalls in "Bootstrap Push Token via Gist + Credential Store" above.

When you have a token hosted as a GitHub Gist (secret), you can do a one-shot push without interactive prompts:

```bash
# Download token to temp file
mkdir -p /tmp/.hermes-verify
curl -sL <GIST_RAW_URL> > /tmp/.hermes-verify/token
TOKEN=*** /tmp/.hermes-verify/token | tr -d '\n')

# Configure credential helper to use the token
printf 'https://oauth2:%s@github.com\n' "$TOKEN" > /tmp/.hermes-verify/creds
git config credential.helper store --file=/tmp/.hermes-verify/creds

# Push (askpass won't trigger because store has the match)
git push origin main
rc=$?

# Cleanup
rm -f /tmp/.hermes-verify/token /tmp/.hermes-verify/creds
git config --unset credential.helper 2>/dev/null
exit $rc
```

### Pitfall: Race between token write and cleanup

Do NOT reuse temp paths across download and cleanup steps in the same script. We hit a case where `rm -f /tmp/.gh_token` on a prior line wiped the token file before it was read by `git push`. Always download to a fresh file, read it, push, THEN clean up — never clean up mid-flow.

### Pitfall: "Invalid username or token" on push

```
remote: Invalid username or token. Password authentication is not supported for Git operations.
```

This error means the token was sent but rejected. Common causes:
- Token expired or revoked
- Token has no `repo` scope (needs `Contents - Read and write` + `Metadata - Read and write` for fine-grained PATs)
- Token owner lacks push access to the repo
- Token file had trailing whitespace/newline (use `tr -d '\n'` after cat)

Verify token is valid: `curl -s -H "Authorization: bearer *** /tmp/.hermes-verify/token | tr -d '\n')" https://api.github.com/user | head -5`
