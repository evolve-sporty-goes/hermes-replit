# GitHub Push Protection — Auto-Remediation in Sync Script

When `git push` is rejected by GitHub secret scanning, the sync script now automatically detects blocked files and adds them to `.gitignore`.

## How It Works

The workspace sync section (Phase 2) wraps `git push` in an error handler:

```bash
push_output=$(git push origin main 2>&1) || {
    echo "$push_output"
    
    # Extract file paths from push protection error
    blocked_files=$(echo "$push_output" | grep -oP 'path:\s+\K\S+' | cut -d: -f1 | sort -u)
    
    if [ -n "$blocked_files" ]; then
        while IFS= read -r blocked_file; do
            rel_path="${blocked_file#$WORKSPACE/}"
            if grep -qF "$rel_path" "$GITIGNORE" 2>/dev/null; then
                echo "  SKIP (already present): $rel_path"
            else
                echo "$rel_path" >> "$GITIGNORE"
                echo "  ADDED: $rel_path"
            fi
        done <<< "$blocked_files"
        
        git add "$GITIGNORE"
        git commit -m "auto: add secret-blocked files to gitignore"
        git push origin main 2>&1 || echo "WARN: Push still failing."
    fi
}
```

## Parsing Logic

GitHub push protection error format:
```
remote: —— Cloudflare Account API Token ——————————————————————
remote:   - commit: 0b81e934e2aa3b6edc866100ecce6865dedf0e76
remote:     path: scripts/setup_cloudflare.sh:13
```

The regex `grep -oP 'path:\s+\K\S+'` extracts `scripts/setup_cloudflare.sh:13`, then `cut -d: -f1` gives `scripts/setup_cloudflare.sh`.

## Limitation: History Still Contains Secrets

`.gitignore` only prevents **future** tracking. If the secret is already in a previous commit, the push will still fail after adding to `.gitignore`. You must rewrite git history to fully resolve:

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter '
  git rm --cached --ignore-unmatch <file1> <file2>
' --prune-empty --tag-name-filter cat -- --all

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force origin main
```

See `references/push-protection-history-rewrite.md` for the full history rewrite workflow.

## What Gets Added

Only files that GitHub explicitly flags in the push protection error. The script checks for duplicates before adding. Files already in `.gitignore` are skipped with a "SKIP (already present)" message.
