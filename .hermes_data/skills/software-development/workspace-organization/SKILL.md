---
name: workspace-organization
description: Organize user-created files into logical directory structures on Replit NixOS while respecting system-managed directories.
trigger: organizing files, restructuring workspace, moving files into directories, cleaning up project layout, file organization on Replit
version: 3
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
- `.gitignore` sensitive block — lists files synced to hermes-secrets repo (parsed by `scripts/sync`)

## Recommended Structure

```
workspace/
├── credentials/      # All secrets, API keys, PATs
├── docs/             # Reference docs, instructions
├── scripts/          # All automation scripts
├── <project>/        # Standalone projects (Go, etc.)
├── .gitignore        # Keep at root (contains sensitive block for sync)
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
- `.gitignore` sensitive block — update ALL paths listed since sync.sh parses this block
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
3. Validates all paths in `.gitignore` sensitive block exist on disk
4. Validates all expected files exist at their new locations
5. Runs `git check-ignore` on each sensitive file to confirm `.gitignore` works

## Symlink vs Hard Link for PATH-accessible Scripts

When making scripts in `scripts/` available in a PATH directory like `$HOME/workspace/.pythonlibs/bin`:

### Symlink (preferred for most cases)
```bash
ln -sf $HOME/workspace/scripts/* "$BIN"
```
- ✅ Works across filesystems/mounts
- ✅ Can link directories
- ✅ `ln -sf` is idempotent (safe to re-run)
- ❌ Dangling if original deleted
- ❌ `chmod +x` must be re-run for new files

### Hard link (when you need file identity)
```bash
for f in $HOME/workspace/scripts/*; do
  [ -f "$f" ] && ln -f "$f" "$BIN/$(basename "$f")"
done
```
- ✅ Survives original deletion (data persists until all links gone)
- ✅ Same inode — no "which is real?" confusion
- ✅ Directories are rejected (good when you don't want subdirs linked)
- ❌ Must be same filesystem (fails on Replit if source/dest on different mounts)
- ❌ Can't link directories

### Auto-chmod new scripts
Since `chmod +x` only affects files existing at execution time, use one of:
1. **Re-run on every boot** (simplest for Replit — add to `hermes.sh`)
2. **inotifywait watcher** (event-driven, zero CPU):
   ```bash
   inotifywait -m -e create -e moved_to --format '%w%f' \
     $HOME/workspace/scripts/ | while read f; do chmod +x "$f"; done &
   ```
3. **Busy-wait loop** (not recommended — wastes CPU):
   ```bash
   while true; do chmod +x $HOME/workspace/scripts/*; sleep 5; done &
   ```

## Pitfall: awk Rule Ordering in .gitignore Parsers

When extracting the sensitive block from `.gitignore` with `awk`, naive multi-rule patterns silently drop entries after comment lines. The compound-rule form with `substr`/`length` checks is required:

```awk
# CORRECT — single compound rule, no rule-ordering issues
awk 'BEGIN{flag=0} /# Sensitive/{flag=1; next} flag==1{ if(substr($0,1,1)=="#") next; if(length($0)>0) print}'

# BROKEN — rule ordering causes entries after comments to be lost
awk '/# Sensitive/{flag=1; next} /^$/{flag=0} flag && !/^#/ && /\S/{print}'
```

## Pitfall: Truncated Lines During Edits

When using `patch` tool, if `old_string` is too short or ambiguous, it can produce truncated output (e.g., a curl `-H` line cut mid-string). Always:
1. Read the full file after patching to verify line integrity
2. Run `bash -n <script>` on all modified shell scripts
3. Run `python3 -m py_compile <script>` on all modified Python scripts
4. Check that multi-line commands (curl with `\`, heredocs) are complete

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
9. **Update `.gitignore` sensitive block** — all paths must point to new locations (sync.sh parses this block)
10. Run verification script to confirm no broken references remain

## Adding Files to an Existing Repo from Within the Workspace

The most common repo operation is **not** cloning — it's adding or modifying files when the workspace is already a clone of the target repo.

### Detect: Is this workspace already a repo clone?

```bash
git remote get-url origin    # shows the remote URL
git status                   # shows branch and untracked files
```

If the remote points to the target GitHub repo, **do not clone again** — work in place.

### Workflow: Add a file and push

```bash
# 1. Create or edit the file (write_file, heredoc, agent file tools)
# 2. Stage, commit, push
git add README.md
git commit -m "Add README.md"
git push origin main
```

### When gh auth is unavailable but you need read-only repo inspection

`gh repo view` may fail if not authenticated, but the GitHub REST API works without auth for public repos:

```bash
# Repo metadata (description, language, default branch, topics)
curl -s https://api.github.com/repos/owner/repo | python3 -c "..."

# List files in a directory
curl -s https://api.github.com/repos/owner/repo/contents/path | python3 -c "..."

# Read a file's content (base64 encoded)
curl -s https://api.github.com/repos/owner/repo/contents/path/to/file | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
print(base64.b64decode(r['content']).decode())
"
```

This lets you inspect the repo's structure to understand what kind of README or docs are appropriate before writing them.

### Writing a README from scratch

When adding a README to a repo with no description:
1. Fetch repo structure via API `contents/` endpoint
2. Read key files (`.replit`, `scripts/main.sh`, `docs/*.txt`) to understand purpose
3. Read `.gitignore` to understand what's tracked vs sensitive
4. Write README covering: overview, structure, getting started, ports/services, security
5. Keep it concise but informative — the user's repos are automation-heavy workspaces

### Pitfall: README goes in .gitignore sensitive block

After adding README.md, the `sensitive` skill's scan should NOT include it. A README is documentation, not a secret. No `.gitignore` changes needed.

## Related Skills

- **`sensitive`** — for scanning the workspace for secrets/tokens/credentials and keeping `.gitignore` sensitive block in sync. Use after completing workspace reorganization to re-scan sensitive credentials.
- **`github-repo-management`** — for pushing to GitHub when push protection blocks due to secrets in git history (bundled skill — has cross-reference to `sensitive/references/push-protection-history-rewrite.md`).

### Pitfall: commit + push without confirming remote

Before pushing, always verify `git remote get-url origin` points to the intended target. In multi-remote setups (e.g., `gitsafe-backup` + `origin`), wrong remote causes pushes to nonexistent remotes.

## Reference

- `references/replit-reorganization-example.md` — full session example with file mapping table and chain-effect documentation
- `references/verify-paths.py` — reusable path-consistency verification script (checks old paths gone, new paths present, .gitignore sensitive block validity, git check-ignore)
- `references/gitignore-sensitive-block-sync.md` — how sync reads .gitignore sensitive block instead of sensitive.txt (parsing logic, format rules, design decisions)
- `references/github-api-read-only-inspection.md` — using GitHub REST API without auth to inspect repo structure (metadata, directory listings, file contents)
