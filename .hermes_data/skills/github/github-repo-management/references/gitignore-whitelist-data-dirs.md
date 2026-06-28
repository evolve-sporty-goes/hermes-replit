# Gitignore Whitelist Pattern for Data Directories

When you need to track only specific files inside a data/state directory (like `.hermes_data`, `.cursor`, or any dir that accumulates runtime artifacts), use a **whitelist** `.gitignore` pattern.

## Pattern

```gitignore
# Ignore everything in the data dir, then whitelist essentials
.data_dir/*
!.data_dir/config.yaml
!.data_dir/.env
!.data_dir/state.db
!.data_dir/SOUL.md
!.data_dir/cron/
!.data_dir/memories/
!.data_dir/skills/
```

## Critical Gotchas

### 1. The `.*` trap

If the data directory itself starts with a dot (e.g., `.hermes_data/`), the catch-all `.*` pattern at the top of your `.gitignore` will match **every file inside it** because the parent directory starts with `.`.

```gitignore
.*          # This matches .hermes_data/anything because the path contains a dotfile component
```

This means your `!` overrides won't work unless they come **after** the `.*` pattern. In git, once a file is matched by an ignore pattern, a later `!` pattern can un-ignore it — but the `.*` pattern must not be the last match.

**Safe approach:** Put your whitelist `!` patterns **after** any `.*` or broad catch-all patterns.

### 2. `git rm --cached` is required for already-tracked files

`.gitignore` only prevents **new** files from being added. If a file is already tracked by git, adding it to `.gitignore` does nothing — you must explicitly remove it from the index:

```bash
git rm --cached path/to/file
```

To find and untrack all non-essential files in a directory:

```bash
git rm -r --cached .hermes_data/logs/
git rm -r --cached .hermes_data/cache/
```

### 3. Directory un-ignore requires the parent to be un-ignored

Git won't re-include a file if its parent directory is excluded. But `.data_dir/*` only matches direct children (not the directory itself), so `!.data_dir/cron/` correctly un-ignores the directory entry, allowing its contents to be tracked again.

**Do not use `.data_dir/**`** — that would also match subdirectories recursively and make `!` overrides for nested paths fail.

### 4. Verification

```bash
# Check if a specific file is ignored (should return the path for ignored files)
git check-ignore -v .hermes_data/config.yaml

# Check for untracked files (should be empty after cleanup)
git status --porcelain --untracked-files=all .hermes_data/

# List tracked files in the data dir
git ls-files .hermes_data/
```

## When to Use This

- Agent data directories (`.hermes_data/`, `.cursor/`) where you want to version configs but not runtime artifacts
- Projects with SQLite databases where only the schema/config matters
- Monorepos with per-agent state that accumulates logs, caches, dumps

## Common Mistake: broad un-ignores

```gitignore
# WRONG: this un-ignores everything, defeating the whitelist
!.hermes_data/
!.hermes_data/*
!.hermes_data/**/*
```

If you have these lines AND a `.*` pattern, the order matters. The safest approach is to **remove** broad un-ignores and rely solely on specific `!` patterns after the `.data_dir/*` ignore rule.
