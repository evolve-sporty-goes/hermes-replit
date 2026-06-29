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

### Sync Script Resolution Logic

1. Strip trailing slash from entry
2. If path doesn't start with `/`, prepend `$WORKSPACE` (usually `/home/runner/workspace`)
3. If resolved path is a **directory**: `find` all non-hidden files at depth 1, sync each individually
4. If resolved path is a **file**: sync directly
5. If path doesn't exist: warn and skip

### Sync Decision (per file)

- Compare local mtime vs repo last commit time
- Local newer → push to repo
- Repo newer → pull to local
- Contents match → no-op
- One side missing → bootstrap from other

### Key Constraint

`.gitignore` uses bare/relative names because that's what gitignore syntax requires. The sync script must resolve these to absolute paths at runtime. Never use absolute paths in `.gitignore` sensitive block — they won't work as gitignore patterns.
