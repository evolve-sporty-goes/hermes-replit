# Purging Sensitive Files from Git History

## When to use

Sensitive files (credentials, tokens, API keys, auth files) were committed to git before being added to `.gitignore`. They exist in the commit history even though they're now ignored. Use this procedure to completely remove them from all commits so they never appear in `git log -- <file>`.

## Prerequisites

- `git-filter-repo` (install: `pip install git-filter-repo`)
- All current changes committed and pushed
- `.gitignore` already lists the sensitive files (so they won't be re-added)

## Procedure

### 1. Stop any auto-sync watcher first

```bash
# Check for running sync
ps aux | grep sync.sh | grep -v grep
# Kill if running
kill $(cat .auto_push_pid 2>/dev/null) 2>/dev/null
# Check cron
# (use cronjob tool: action=list)
```

### 2. Commit and push current state

```bash
git add -A
git commit -m "auto-sync: <timestamp>"
git push origin main
```

### 3. Identify which sensitive files have history

```bash
# Check each file listed in .gitignore's sensitive section
git log --all --oneline -- email.sh .pat .hermes_data/.env .hermes_data/auth.json openrouter_credentials.txt firecrawl_credentials.txt
```

### 4. Purge with git-filter-repo

```bash
git filter-repo --invert-paths \
  --path email.sh \
  --path .hermes_data/auth.json \
  --path openrouter_credentials.txt \
  --path firecrawl_credentials.txt \
  --path .hermes_data/.env \
  --path .pat \
  --force
```

`--invert-paths` means "remove these paths from ALL commits." `--force` is required when the repo has no fresh clone (running in the existing working directory).

### 5. Re-add origin remote (filter-repo removes it)

```bash
git remote add origin https://github.com/<owner>/<repo>
```

### 6. Force push the rewritten history

```bash
git push origin main --force
```

**Warning:** This rewrites history. Anyone with a local clone must re-clone or `git reset --hard origin/main`.

### 7. Verify

```bash
# Should return 0 lines
git log --all --oneline -- email.sh .hermes_data/auth.json openrouter_credentials.txt

# Files still exist in working directory
ls -la email.sh openrouter_credentials.txt

# Files are still ignored
git status  # should NOT show the sensitive files as untracked
```

## Pitfalls

- **filter-repo removes the `origin` remote** — always re-add it before pushing
- **filter-repo removes ALL remotes** — if you have multiple remotes (e.g. a backup), re-add them all
- **Files still exist in working directory** — filter-repo only removes from git history, not the filesystem. The files remain on disk (which is usually what you want — they're still needed at runtime)
- **Files must be in `.gitignore`** — otherwise the next `git add -A` will re-commit them
- **Large repos take time** — filter-repo parses every commit; repos with 1000+ commits may take 10-30 seconds
- **Force push requires approval** — on Replit, the user must approve the force push in the terminal
- **Do NOT use `git filter-branch`** — it's deprecated, slower, and produces warnings. `git-filter-repo` is the modern replacement
- **Backup remote** — if you have a `gitsafe-backup` or similar secondary remote, it will also lose the history. That's fine — the goal is to eliminate the sensitive data everywhere

## Integration with sync.sh workflow

When `sync.sh` auto-commits and pushes, sensitive files that are NOT yet in `.gitignore` can get committed. The fix is:

1. Add the file to `sensitive.txt`
2. Run sync.sh's `.gitignore` update (it auto-generates the sensitive block)
3. Run the purge procedure above to remove the file from all prior commits
4. Verify with `git log --all --oneline -- <file>` (should be empty)
