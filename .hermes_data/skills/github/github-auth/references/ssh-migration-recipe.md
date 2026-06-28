# SSH Migration Recipe (Real-World Example)

Complete walkthrough for migrating a GitHub remote from HTTPS (PAT) to SSH, as performed in a pairing session.

## Trigger

Push fails with:
```
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/...'
```

## Steps

### 1. Generate SSH key

```bash
ssh-keygen -t ed25519 -C "<email>" -f ~/.ssh/id_ed25519 -N ""
```

### 2. Show public key for user to add to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

User adds it at: https://github.com/settings/keys

### 3. Trust GitHub's host key

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
```

**Without this step**, the next push fails with:
```
Host key verification failed.
fatal: Could not read from remote repository.
```

### 4. Switch remote URL

```bash
git remote set-url origin git@github.com:<owner>/<repo>.git
```

### 5. Verify

```bash
ssh -T git@github.com
git push
```

## Common Pitfalls

- **Forgetting `ssh-keyscan`**: The most common mistake. The error message is misleading — it looks like an auth problem but is actually a host key trust issue.
- **PAT in chat**: If a user pastes a live PAT into chat to fix the initial push failure, remind them to revoke it immediately — it's now in terminal history and conversation context.
- **Existing `~/.git-credentials`**: After switching to SSH, old HTTPS tokens in `~/.git-credentials` are harmless but can be cleaned up with `git credential reject`.

## Security Note

Always remind users to revoke PATs they pasted into chat. The token is visible in:
- Terminal scrollback
- Shell history (if not using `unset HISTFILE` before pasting)
- Conversation context (agent logs, session store)
