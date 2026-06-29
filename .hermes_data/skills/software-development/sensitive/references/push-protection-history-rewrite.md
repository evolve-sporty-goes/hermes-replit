# GitHub Push Protection & History Rewrite

When pushing to a repo with GitHub Push Protection enabled, commits containing secrets (API keys, tokens) will be rejected. This guide covers removing secrets from git history.

## Pattern: Filter → Push → Discover → Repeat

Push protection reveals secrets iteratively. Each push attempt exposes the next file/location:

```
1. git filter-repo to remove obvious secret files
2. git push --force
3. GitHub blocks again with new location
4. Add that file pattern to the filter
5. Repeat until push succeeds
```

## Preferred: `git filter-repo` (fast, clean)

`git filter-repo` is available on Replit via pip and is dramatically faster and safer than `git filter-branch`. It removes files from ALL commits in one pass and auto-cleans.

### Step-by-Step with filter-repo

#### 1. Identify the offending files

GitHub push protection error will list:
- Commit SHA
- File path + line number
- Secret type (e.g., "Cloudflare User API Token")

#### 2. Install filter-repo (if needed)

```bash
pip install git-filter-repo
```

#### 3. Commit any unstaged work first

```bash
git add -A && git commit -m "checkpoint: pre-filter"
```

#### 4. Run filter-repo to remove files from all history

```bash
git filter-repo --invert-paths --path <file1> --path <file2> --force
```

- `--invert-paths` = remove these paths (keep everything else)
- `--path` = file or directory to remove (repeat for multiple)
- `--force` = required if repo was not freshly cloned

#### 5. Re-add remote (filter-repo removes it)

```bash
git remote add origin https://github.com/org/repo.git
```

#### 6. Force push

```bash
PAT=$(cat credentials/.pat)
ASKPASS=$(mktemp)
printf '#!/bin/bash\necho %s\n' "$PAT" > "$ASKPASS"
chmod +x "$ASKPASS"
GIT_ASKPASS="$ASKPASS" git push origin main --force
rm -f "$ASKPASS"
```

#### 7. Verify

```bash
git log --all -- <file1> <file2>  # should return nothing
```

## Fallback: `git filter-branch` (when filter-repo unavailable)

### 1. Rewrite history to remove secrets

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter '
  git rm --cached --ignore-unmatch <file1> <file2> ...
' --prune-empty --tag-name-filter cat -- --all
```

### 2. Clean up after filter-branch

```bash
# Delete old refs backed up by filter-branch
for ref in $(git for-each-ref --format='%(refname)' refs/original/); do
  git update-ref -d "$ref"
done

# Expire reflogs and garbage collect to truly erase the old commits
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### 3. Prevent re-commitment

Add files to `.gitignore` so they don't get re-added:

```bash
echo "<file_pattern>" >> .gitignore
git add .gitignore && git commit -m "chore: prevent secrets in git history"
```

### 4. Force push

```bash
PAT=$(cat credentials/.pat)
git push --force https://username:${PAT}@github.com/org/repo.git main
```

## Solving the "unstaged changes" Problem

If filter-branch fails with *"Cannot rewrite branches: You have unstaged changes"*, it's often because a running process (like Hermes agent) keeps writing to log/session files.

**Fix — use `git update-index --assume-unchanged`:**

```bash
# Tell git to ignore ongoing writes to these files
git update-index --assume-unchanged .hermes_data/logs/agent.log
git update-index --assume-unchanged .hermes_data/logs/errors.log
git update-index --assume-unchanged .hermes_data/webui/sessions/*.json
git update-index --assume-unchanged .hermes_data/webui/sessions/_run_journal/*/*.jsonl

# Now run filter-branch
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter '
  git rm --cached --ignore-unmatch <files>
' --prune-empty --tag-name-filter cat -- --all

# Restore normal tracking when done
git update-index --no-assume-unchanged <files>
```

From this workspace's experience:

| File | Secret Type | Why |
|------|-------------|-----|
| `freellmapi` | Cloudflare API Token + frellmapi key | Hardcoded script with credentials |
| `.hermes_data/config.yaml` | Cloudflare API Token | `hermes config set cloudflare.apiKey "..."` |
| `.hermes_data/webui/sessions/**` | Any secrets mentioned in conversation | Session logs capture all agent/user conversation |

**Add all of these to `.gitignore`:**

```gitignore
# Never commit secrets
freellmapi
.hermes_data/config.yaml
.hermes_data/webui/sessions/
```

## Filtering Edits Inside Files (not just removing files)

If a secret is embedded inside a tracked config file (e.g., `config.yaml` has 600+ lines but only 2 lines contain secrets), use `git filter-branch` with `--tree-filter` to edit:

```bash
# Remove lines containing a pattern from a file across all commits
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --tree-filter '
  if [ -f .hermes_data/config.yaml ]; then
    sed -i "/cloudflare.apiKey/d" .hermes_data/config.yaml
  fi
' --prune-empty --tag-name-filter cat -- --all
```

**Warning**: `--tree-filter` checks out each commit, so it's much slower than `--index-filter`. Use `--tree-filter` only when you need to edit file contents (not just remove files).

## Alternative BFG Repo Cleaner (when filter-branch is too slow)

For large repos, the [BFG Repo Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) is faster:

```bash
# Remove specific files
java -jar bfg.jar --delete-files freellmapi

# Remove secrets by pattern (replaces with ***REMOVED***)
java -jar bfg.jar --replace-text passwords.txt

# Then clean up
git reflog expire --expire=now --all
git gc --prune=now
```

BFG may not be available on Replit NixOS (no custom Java packages). `git filter-branch` is usually sufficient for small repos (<50 commits).
