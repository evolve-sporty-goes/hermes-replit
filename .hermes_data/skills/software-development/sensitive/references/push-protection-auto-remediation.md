# GitHub Push Protection — Auto-Remediation in Sync Script

When `git push` is rejected by GitHub secret scanning, the sync script automatically detects blocked files, adds them to `.gitignore`, strips them from git history via `git filter-repo`, re-adds the `origin` remote, re-sets up HTTPS auth, and force-pushes.

## How It Works

The workspace sync section wraps `git push` in an error handler:

```bash
push_output=$(git push origin main 2>&1) || {
    echo "$push_output"

    # Extract file paths from push protection error
    blocked_files=$(echo "$push_output" | grep -oP 'path:\s+\K\S+' | cut -d: -f1 | sort -u)

    if [ -n "$blocked_files" ]; then
        echo "SECRET BLOCK detected. Stripping from history with git-filter-repo:"

        filter_args=()
        while IFS= read -r blocked_file; do
            rel_path="${blocked_file#$WORKSPACE/}"
            filter_args+=(--path "$rel_path")

            if grep -qF "$rel_path" "$GITIGNORE" 2>/dev/null; then
                echo "  SKIP gitignore (already present): $rel_path"
            else
                echo "$rel_path" >> "$GITIGNORE"
                echo "  ADDED to gitignore: $rel_path"
            fi
        done <<< "$blocked_files"

        # Strip entire state-snapshots dir (always contains secrets)
        filter_args+=(--path ".hermes_data/state-snapshots" --invert-paths)

        # Rewrite git history to remove blocked paths
        git filter-repo --force "${filter_args[@]}"

        # CRITICAL: filter-repo removes origin remote — re-add it
        git remote add origin "https://github.com/org/repo.git"

        # Re-setup HTTPS askpass auth (filter-repo does NOT preserve credential helpers)
        if [ -f "$PAT_FILE" ] && [ -s "$PAT_FILE" ]; then
            TMPDIR=$(mktemp -d); trap "rm -rf $TMPDIR" EXIT
            ASKPASS="$TMPDIR/git-askpass"
            printf '#!/bin/bash\n%s\n' "$(cat "$PAT_FILE")" > "$ASKPASS"
            chmod +x "$ASKPASS"
            export GIT_ASKPASS="$ASKPASS"
        fi

        # Stage .gitignore updates
        git add "$GITIGNORE"
        if ! git diff --cached --quiet; then
            git commit -m "auto: add secret-blocked files to gitignore"
        fi

        # Force-push rewritten history
        git push --force origin main 2>&1 || echo "WARN: Force push failed."
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

## Why History Rewrite Is Required

`.gitignore` only prevents **future** tracking. If the secret is already in a previous commit, the push will still fail after adding to `.gitignore`. You must rewrite git history to fully resolve.

The sync script uses `git filter-repo` (not `git filter-branch`) because:
- Dramatically faster (rewrites 50 commits in ~3s vs minutes for filter-branch)
- Auto-cleans old objects and refs
- `--invert-paths` syntax is intuitive: specify what to remove, keep everything else

## Critical Pitfall: `origin` Removal + Auth Loss

After `git filter-repo`:
1. `origin` remote is deleted — push will fail with `fatal: 'origin' does not appear to be a git repository`
2. HTTPS credential helpers are NOT preserved — push will hang waiting for password or fail auth

**Always** re-add origin and re-setup `GIT_ASKPASS` (or equivalent) before pushing. See `references/push-protection-history-rewrite.md` for the full pattern.

## What Gets Filtered

The sync script filters:
1. Each file GitHub explicitly flags in the push protection error (converted to relative paths)
2. The entire `.hermes_data/state-snapshots` directory (preventive — config snapshots taken during updates always contain live credentials)

## Sync Script Output Format

The sync script uses **basename** (not full path) in its per-file output:
```
OK (B): .pat — identical
PUSH (C): state.db → local newer (1782719097 > 1782718651)
PULL (A): .env ← bootstrapping from repo
WARN: '/home/runner/workspace/brave-browser' not found, skipping
SECRET BLOCK detected. Stripping from history with git-filter-repo:
  SKIP gitignore (already present): .hermes_data/state-snapshots/.../auth.json
  SKIP gitignore (already present): .hermes_data/state-snapshots/.../config.yaml
  SKIP gitignore (already present): .hermes_data/state-snapshots/.../.env
Force-pushing rewritten history...
```

Format: `ACTION (Case): filename — details`

User prefers basename (short filename) over full path in sync output.

See also: `references/push-protection-history-rewrite.md` for the full `git filter-repo` workflow including the origin/auth pitfall.
See also: `references/sync-gitignore-integration.md` for how `scripts/sync` reads `.gitignore` and resolves bare directory/file names to full paths.
