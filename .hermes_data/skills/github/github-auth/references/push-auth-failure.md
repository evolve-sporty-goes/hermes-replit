# Push Authentication Failure — Resolution Recipe

## Symptom

```
$ git push origin main
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/owner/repo.git/'
```

This means the credential git has on file is either missing, expired, or was rejected by the host. It is NOT a network or repo-existence problem.

## Root Causes

1. **Token expired or was revoked** — GitHub PATs have an expiration date; a previously working token may have lapsed.
2. **Token never stored** — `credential.helper` was not configured, so git has nothing to send.
3. **Wrong remote host** — Pushing to a self-hosted GitHub Enterprise or a non-github.com remote (e.g. `https://git.example.com/...`) requires credentials for that host, not github.com.
4. **Token lacks scope** — The PAT exists but doesn't have `repo` scope for the target repo.

## Resolution Options

### First push for a branch (no upstream)

```
fatal: The current branch main has no upstream branch.
```

Not an auth error — the branch just hasn't been pushed before. Fix:

```bash
git push -u origin main
# or
git push --set-up-stream origin main
```

### Option A: Embed a PAT in the Remote URL (fastest)

```bash
git remote set-url origin https://<username>:<PAT>@<host>/<owner>/<repo>.git
git push origin main
```

- Get a PAT from https://github.com/settings/tokens (or your host's equivalent).
- Scopes needed: `repo`, `workflow` (if using Actions).
- The token is stored in plaintext in `.git/config` — acceptable for personal machines, not for shared.

### Option B: Switch to SSH (no token storage)

```bash
git remote set-url origin git@<host>:<owner>/<repo>.git
git push origin main
```

Prerequisites:
- SSH key exists: `ls ~/.ssh/id_*.pub`
- Public key is registered at https://github.com/settings/keys (or host equivalent)
- Test: `ssh -T git@<host>` → "Hi <username>! You've successfully authenticated..."

### Option C: Re-store with credential helper

```bash
git config --global credential.helper store
git ls-remote https://<host>/<owner>/<repo>.git
# Enter username (prompt) and PAT (as password). Saved after first use.
```

## Detection Flow

```bash
# 1. What remote are we pushing to?
git remote -v

# 2. What credentials does git have?
git config --global credential.helper
cat ~/.git-credentials 2>/dev/null || echo "no stored credentials"

# 3. Is GITHUB_TOKEN set in environment?
echo "${GITHUB_TOKEN:-not set}"

# 4. Is gh authenticated?
gh auth status 2>/dev/null || echo "gh not available or not authenticated"
```

## Replit / Headless Environments Without SSH

Replit containers often lack SSH keys and cannot run `sudo apt-get` to install them. When the user needs to push from such an environment:

### Option: GitHub Secret Gist as Ephemeral Token Delivery

1. User creates a **secret gist** at https://github.com with the PAT as the only content.
2. Grab the raw URL (e.g. `https://gist.githubusercontent.com/<user>/<id>/raw/<token>`).
3. Agent fetches it to a temp file and uses a git credential helper:

```bash
curl -sL "<raw-gist-url>" > /tmp/gh-token
git config credential.helper "file --file=/tmp/gh-token"
git push origin main
rm -f /tmp/gh-token
git config --unset credential.helper
```

**Why this is safe:**
- Secret gists are not indexed by search engines or listed on the user's profile.
- The token never appears in shell history, `.git/config`, or commit metadata.
- The temp file is deleted immediately after use.
- The user can delete the gist on GitHub after the push succeeds.

**Pitfall:** If the user pastes the token directly into chat, it's in the transcript and terminal history. Always route through the gist, never through inline paste.

**User workflow preference:** Always prefer file-based token passing (gist → temp file → credential helper) over inline tokens in URLs or chat. The user explicitly rejected embedding tokens in URLs as a security concern. When the user references a token from a past session, retrieve it from the file/gist source they used — do not ask them to paste it again.

### Fallback: Switch remote to HTTPS + credential helper

If the user can provide a token via a file upload (not chat), switch the remote to HTTPS and configure `credential.helper store`:

```bash
git remote set-url origin https://github.com/<owner>/<repo>.git
git config --global credential.helper store
# First push prompts for credentials; token is saved for subsequent pushes
```

## Notes for Agents

- When a user says "git push fails" and the error is auth-related, **always check the remote URL first** — a non-github.com host means the standard `GITHUB_TOKEN` env var won't apply.
- If the user has a PAT but the push still fails, check the token's **scopes** at the GitHub settings URL.
- SSH is the more robust long-term fix for agents that push frequently — no expiration, no token storage in plaintext.
- In Replit/headless environments where SSH is unavailable, use the secret-gist delivery pattern above.
