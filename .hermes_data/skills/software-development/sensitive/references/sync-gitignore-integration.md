# Sync Script ↔ .gitignore Integration

## Architecture

The sync script (`scripts/sync`) reads sensitive file paths from `.gitignore`'s sensitive block — NOT from `sensitive.txt`.

### .gitignore Sensitive Block Format

```gitignore
# Sensitive files (auto-managed by sensitive skill — do not edit)
# Synced to hermes-secrets repo via sync.sh
credentials/.pat
credentials/.supabase_anon_key
brave-browser/
.hermes_data/webui/sessions/
```

- Block starts after a line containing `# Sensitive`
- Block ends at next blank line or non-comment line
- Comment-only lines within block are skipped
- Entries use **relative paths** from workspace root
- Directories use **trailing slash** (e.g. `brave-browser/`)

### Extracting the Sensitive Block from .gitignore

The sync script uses `awk` to extract entries from the sensitive block:

```bash
awk '/^# Sensitive/{f=1;next} f&&/^#/{next} f&&/^---/{next} f&&length{print}' "$GITIGNORE"
```

This:
- Sets `f=1` after matching a line starting with `# Sensitive`
- Skips comment-only lines within the block (`/^#/`)
- Skips divider lines (`/^---/`)
- Skips blank lines (`length`)
- Prints everything else (the actual entries)
- Runs to EOF (no blank-line terminator needed)

### Sync Script Resolution Logic

1. Strip trailing slash from entry
2. **Identify workspace root** via `dirname "$GITIGNORE"` (wherever `.gitignore` lives is the root)
3. If path doesn't start with `/`, prepend `$WORKSPACE`
4. If resolved path is a **directory**: `find` all non-hidden files at depth 1, sync each individually
5. If resolved path is a **file**: sync directly
6. If path doesn't exist: warn and skip

**Key detail:** The workspace root is derived from `.gitignore`'s directory, NOT hardcoded as `/home/runner/workspace`. This makes the script portable.

### Sync Decision (per file)

- Compare local mtime vs repo last commit time
- Local newer → push to repo
- Repo newer → pull to local
- Contents match → no-op
- One side missing → bootstrap from other

### Key Constraint

`.gitignore` uses bare/relative names because that's what gitignore syntax requires. The sync script must resolve these to absolute paths at runtime. Never use absolute paths in `.gitignore` sensitive block — they won't work as gitignore patterns.
