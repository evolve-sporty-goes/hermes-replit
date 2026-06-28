# Git SSH Migration on Replit

When `git push` fails on Replit with an HTTPS auth error, the fix is to switch to SSH.

## Error Pattern

```
error: unable to read askpass response from 'replit-git-askpass'
fatal: could not read Username for 'https://github.com': No such device or address
```

This happens because Replit's environment injects a `replit-git-askpass` script that intercepts git credential prompts but has no credentials to supply (no PAT configured, or the user prefers SSH).

## Fix

Switch the remote from HTTPS to SSH:

```bash
git remote set-url origin git@github.com:<owner>/<repo>.git
```

Then verify SSH connectivity:

```bash
ssh -T git@github.com
```

If that fails with `Host key verification failed`:

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
```

Then retry:

```bash
git push
```

## When This Applies

- Replit container with no GitHub PAT configured
- User explicitly prefers SSH over HTTPS
- `replit-git-askpass` is present but non-functional

## See Also

The `github-auth` skill covers full SSH key setup (generation, adding to GitHub, testing) if the user doesn't already have keys on the machine.
