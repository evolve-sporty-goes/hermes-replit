# .gitignore Sensitive Block Sync Pattern

How `scripts/sync` reads the sensitive file list from `.gitignore` instead of a separate `sensitive.txt`.

## Why

- Single source of truth: `.gitignore` already lists sensitive files to exclude from git
- No need to maintain a separate `sensitive.txt` that can drift out of sync
- Adding a file to `.gitignore` automatically includes it in secrets backup

## .gitignore Format

```gitignore
# Sensitive files (auto-managed by sensitive skill — do not edit)
# Synced to hermes-secrets repo via sync.sh
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
- Block runs to EOF or next blank line (no blank line terminator needed)
- Comment-only lines within the block are skipped
- Trailing slashes indicate directories (expanded to individual files)
- All paths are relative to `.gitignore`'s directory (resolved via `dirname "$GITIGNORE"`)

## Parsing Logic (in scripts/sync)

```bash
GITIGNORE="/home/runner/workspace/.gitignore"
WORKSPACE=$(dirname "$GITIGNORE")

# Extract entries from sensitive block: after "# Sensitive" line, skip comment lines, stop at EOF/blank
file_list=$(awk 'BEGIN{flag=0} /# Sensitive/{flag=1; next} flag==1{ if(substr($0,1,1)=="#") next; if(length($0)>0) print}' "$GITIGNORE")

while IFS= read -r entry; do
    entry="${entry%/}"  # strip trailing slash
    [[ "$entry" != /* ]] && entry="$WORKSPACE/$entry"
    
    if [ -d "$entry" ]; then
        # Expand directory: sync each file inside (non-recursive, skip hidden)
        while IFS= read -r -d '' file; do
            sync_file_by_history "$file" "$(basename "$file")"
        done < <(find "$entry" -maxdepth 1 -type f -name "[!.]*" -print0)
    elif [ -f "$entry" ]; then
        sync_file_by_history "$entry" "$(basename "$entry")"
    else
        echo "WARN: '$entry' not found, skipping"
    fi
done <<< "$file_list"
```

## Correct awk Pattern (IMPORTANT)

The naive pattern `/^$/{flag=0}` to stop at blank lines DOES NOT WORK reliably with awk when combined with comment-skipping rules — awk's rule ordering and implicit `next` behavior causes interactions where lines after comments get silently dropped. 

**Working pattern** uses explicit `substr` check and `length` test inside a single compound rule:

```awk
BEGIN{flag=0} /# Sensitive/{flag=1; next} flag==1{ if(substr($0,1,1)=="#") next; if(length($0)>0) print}
```

Avoid these broken alternatives:
- ❌ `/# Sensitive/{flag=1; next} /^$/{flag=0} flag && !/^#/ && /\S/{print}` — rule ordering issue, drops entries after comment lines
- ❌ `/# Sensitive/{flag=1; next} /^$/{flag=0} flag && /^#/{next} flag && /\S/{print}` — still broken, flag is reset before entries are reached

## Key Design Decisions

1. **`awk` over state-machine `while/read`** — simpler, fewer edge cases with blank lines and comments
2. **`dirname "$GITIGNORE"`** for workspace root — no hardcoded paths, works if repo moves
3. **Non-recursive directory expansion** (`-maxdepth 1`) — avoids accidentally syncing nested content
4. **Skip hidden files** (`-name "[!.]"`) — `.gitkeep`, `.DS_Store`, etc. are not secrets
5. **Full paths from `.gitignore` dir** — `credentials/.pat` → `/home/runner/workspace/credentials/.pat`
6. **Sensitive block stays in `.gitignore`** — do NOT strip it; it serves both git and sync
