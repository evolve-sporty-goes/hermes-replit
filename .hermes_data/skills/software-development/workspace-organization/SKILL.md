---
name: workspace-organization
description: Organize user-created files into logical directory structures on Replit NixOS while respecting system-managed directories.
trigger: organizing files, restructuring workspace, moving files into directories, cleaning up project layout, file organization on Replit
version: 2
---

# Workspace Organization (Replit NixOS)

Organize user-created files into logical directory structures while respecting Replit NixOS system-managed directories.

## Protected Directories (NEVER touch)

On Replit NixOS, these directories are system-managed and MUST NOT be moved, renamed, or reorganized:

- `.hermes_data/` — Hermes Agent state, config, skills, sessions, memory
- `.git/` — Git repository metadata
- `.cache/` — Nix/uv/pip cache (symlinked to ~/ to save workspace space)
- `.local/` — Python/user local packages (symlinked)
- `.pythonlibs/` — Virtualenv packages (symlinked, reinstalled by hermes.sh on reset)
- `.config/` — User config (symlinked)
- `.agents/` — Replit agent config
- `.replit/` — Replit project config (can be read but not moved)

Move the USER-CREATED symlinks (`.cache`, `.local`, `.pythonlibs`, `.config`) to `~/` to keep workspace lean. Include `.pythonlibs` in symlink loop — packages reinstalled by hermes.sh on reset anyway.

## Safe to Organize

User-created files at workspace root:
- Credentials files (`*_credentials.txt`, `.pat`, `.supabase_anon_key`, `mail.txt`)
- Scripts (`*.sh`, `*.py`)
- Documentation (`*.md`, `*.txt` instructions)
- Project subdirectories (Go projects, etc.)
- `sensitive.txt` — sync list for hermes-secrets repo

## Recommended Structure

```
workspace/
├── credentials/      # All secrets, API keys, PATs
├── docs/             # Reference docs, instructions
├── scripts/          # All automation scripts
├── <project>/        # Standalone projects (Go, etc.)
├── sensitive.txt     # Keep at root (referenced by sync.sh)
├── .gitignore        # Keep at root
└── .replit/          # Keep at root (system-managed)
```

## CRITICAL: Update Path References After Moving

After reorganizing files, ALL scripts that reference moved files by absolute or relative paths must be updated. This is the most commonly missed step.

### How to Find Broken References

Search every script for the old paths using `search_files`:

```python
search_files(pattern="/home/runner/workspace/email.sh", path="/home/runner/workspace/scripts")
search_files(pattern="/home/runner/workspace/.supabase_anon_key", path="/home/runner/workspace/scripts")
search_files(pattern="/home/runner/workspace/torbox_credentials.txt", path="/home/runner/workspace/scripts")
# ... check every moved file
```

### Common Reference Patterns to Fix

- Shell scripts: `cat /home/runner/workspace/.pat` → `cat /home/runner/workspace/credentials/.pat`
- Python scripts: `CRED_PATH = "/home/runner/workspace/old.txt"` → `CRED_PATH = "/home/runner/workspace/credentials/old.txt"`
- Subprocess calls: `["bash", "/home/runner/workspace/email.sh"]` → `["bash", "/home/runner/workspace/scripts/email.sh"]`
- `sensitive.txt` — update ALL paths listed since sync.sh iterates over it
- Nested references: scripts calling `email.sh` which itself references `mail.txt` — check full chain

### Substring False Positives

When checking if old paths are gone, `mail.txt` will appear inside `/home/runner/workspace/credentials/mail.txt`. The check must verify the OLD path is not present as a standalone reference, not just as a substring of the new path. Use exact string matching per-line, not substring grep.

### Update `.gitignore`

When files move, `.gitignore` rules must be updated to match new locations. Bare-name patterns (e.g., `email.sh`) work by accident because git treats them as `**/email.sh` globs, but they're imprecise and would ignore same-named files in unintended directories. Always use explicit paths:

```
# Bad (bare name — works by accident):
email.sh
.pat

# Good (explicit path):
scripts/email.sh
credentials/.pat
```

Verify with `git check-ignore <path>` — exit code 0 means ignored, non-zero means tracked.

### Verification Script

After fixing, run a verification script (see `references/verify-paths.py` template) that:
1. Reads each modified file and checks old paths are absent (line-exact, not substring)
2. Checks new paths are present
3. Validates all paths in `sensitive.txt` exist on disk
4. Validates all expected files exist at their new locations
5. Runs `git check-ignore` on each sensitive file to confirm `.gitignore` works

## Pitfall: Accidental Directory Creation

When moving files, `mkdir -p` can create directories that shadow or conflict with system-managed paths. Always verify the target directory is intended before creating it. If you accidentally create a directory at root that duplicates a system-managed name (e.g., `skills/`), remove it immediately with `rm -rf`.

## Pitfall: `mv` with Globbing

When moving multiple files with globs, verify each source file exists first. A glob that doesn't match produces an error but doesn't stop the script (without `set -e`). Use explicit paths or check with `ls` before batch moves.

## Workflow

1. List all files at workspace root (excluding system dirs)
2. Categorize: credentials, scripts, docs, projects
3. Create target directories with `mkdir -p`
4. Move files with explicit paths
5. Verify no system-managed directories were touched
6. Verify no empty or duplicate directories remain
7. **Update all path references** (see CRITICAL section above)
8. **Update `.gitignore`** — replace bare-name ignore rules with explicit new paths (e.g., `email.sh` → `scripts/email.sh`)
9. **Update `sensitive.txt`** — all paths must point to new locations (sync.sh iterates over this)
10. Run verification script to confirm no broken references remain

## Reference

- `references/replit-reorganization-example.md` — full session example with file mapping table and chain-effect documentation
- `references/verify-paths.py` — reusable path-consistency verification script (checks old paths gone, new paths present, sensitive.txt validity, git check-ignore)
