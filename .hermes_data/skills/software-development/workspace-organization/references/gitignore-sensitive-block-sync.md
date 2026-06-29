# .gitignore Sensitive Block Sync Pattern

How `scripts/sync` reads the sensitive file list from `.gitignore` instead of a separate `sensitive.txt`.

## Why

- Single source of truth: `.gitignore` already lists sensitive files to exclude from git
- No need to maintain a separate `sensitive.txt` that can drift out of sync
- Adding a file to `.gitignore` automatically includes it in secrets backup

## .gitignore Format

```gitignore
# Sensitive files (auto-managed by sync script — do not edit)
# Synced to hermes-secrets repo via scripts/sync
credentials/.pat
credentials/.supabase_anon_key
credentials/openrouter_credentials.txt
scripts/email.sh
.hermes_data/.env
brave-browser/
freellmapi
```

Rules:
- Block starts with a line containing `# Sensitive`
- Block ends at the next blank line
- Comment-only lines within the block are skipped
- Trailing slashes indicate directories (expanded to individual files)
- All paths are relative to `.gitignore`'s directory

## Parsing Logic (in scripts/sync)

```bash
GITIGNORE="/home/runner/workspace/.gitignore"
WORKSPACE=$(dirname "$GITIGNORE")

file_list=$(awk '/# Sensitive/{flag=1; next} /^$/{flag=0} flag && !/^#/ && /\S/{print}' "$GITIGNORE")

while IFS= read -r entry; do
    entry="${entry%/}"  # strip trailing slash
    [[ "$entry" != /* ]] && entry="$WORKSPACE/$entry"
    
    if [ -d "$entry" ]; then
        # Expand directory to individual files
        while IFS= read -r -d '' file; do
            sync_file_by_history "$file" "$(basename "$file")"
        done < <(find "$entry" -maxdepth 1 -type f -name "[!.]*" -print0)
    elif [ -f "$entry" ]; then
        sync_file_by_history "$entry" "$(basename "$entry")"
    fi
done <<< "$file_list"
```

## Key Design Decisions

1. **`awk` over state-machine `while/read`** — simpler, fewer edge cases with blank lines and comments
2. **`dirname "$GITIGNORE"`** for workspace root — no hardcoded paths, works if repo moves
3. **Non-recursive directory expansion** (`-maxdepth 1`) — avoids accidentally syncing nested content
4. **Skip hidden files** (`-name "[!.]*"`) — `.gitkeep`, `.DS_Store`, etc. are not secrets
5. **Full paths from `.gitignore` dir** — `credentials/.pat` → `/home/runner/workspace/credentials/.pat`
