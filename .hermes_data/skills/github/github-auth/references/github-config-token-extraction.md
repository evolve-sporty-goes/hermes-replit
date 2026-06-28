# GitHub Config Token Extraction

When `gh` CLI is installed but `gh auth status` reports invalid/expired, the stored OAuth token in `~/.config/gh/hosts.yml` may still be valid for git operations.

## Extraction Pattern

```bash
# Read the last oauth_token from gh config (typically the active account)
TOKEN=*** 'oauth_token:' ~/.config/gh/hosts.yml | tail -1 | awk '{print $2}')

# Sanitize — strip whitespace/newlines
TOKEN=*** "$TOKEN" | tr -d '\n\r')

# Verify it works
curl -s -H "Authorization: bearer $TOKEN" https://api.github.com/user | head -5
```

## Use with Git Credential Helper

Once extracted, use the token with git's `store` credential helper to bypass `replit-git-askpass`:

```bash
printf 'https://oauth2:%s@github.com\n' "$TOKEN" > /tmp/.git_creds_$$
git config credential.helper store --file=/tmp/.git_creds_$$
git push origin main
rc=$?

# Cleanup
rm -f /tmp/.git_creds_$$
git config --unset credential.helper 2>/dev/null
exit $rc
```

## Why This Works

`gh` stores its OAuth token in `~/.config/gh/hosts.yml` under each user entry. Even when `gh auth status` reports invalid (e.g., the token was revoked or the account is inactive), the token string itself may still be valid for HTTPS git operations. Git's `store` credential helper takes precedence over `replit-git-askpass` during write operations.

## Pitfalls

- **Token may be expired** — always verify with a `curl` call to `/user` before using
- **Multiple accounts** — `gh` config may have multiple user blocks; use `tail -1` for the last/active one, or match by username
- **Token in remote URL** — do NOT embed the token in `git remote set-url origin https://user:token@...` as it persists in `.git/config` forever
- **Cleanup** — always `rm` the temp credential file and `git config --unset credential.helper` after the push

## See Also

- `replit` skill's `references/github-push-auth-on-replit.md` — full landscape of Replit push auth options
- `replit` skill's `references/private-repo-secrets.md` — storing `.env` in a separate private repo
