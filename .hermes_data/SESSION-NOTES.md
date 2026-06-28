# Session Notes — .hermes_data Cleanup

## 2026-06-25: Cleanup & Gitignore Whitelist

### What was done
1. Deleted non-essential files from `.hermes_data/` (logs, caches, dumps, backups, lsp, temp files)
2. Updated `.gitignore` from broad un-ignore (`!.hermes_data/**/*`) to a **whitelist approach**:
   - `.hermes_data/*` ignores everything by default
   - Specific `!` patterns un-ignore only essential files/dirs
3. Removed all non-essential files from git tracking via `git rm --cached`

### Files kept (whitelist)
- `config.yaml`, `.env`, `auth.json`
- `state.db` (+ `state.db-shm`, `state.db-wal`)
- `SOUL.md`
- `backups/`, `cron/`, `memories/`, `skills/`

### Files ignored
- All logs, caches, request dumps, state snapshots, corrupt backups
- `.hermes_history`, `.update_check`, `.skills_prompt_snapshot.json`
- `lsp/`, `verification_evidence.db`, `*_cache.json`
- Empty dirs: `audio_cache/`, `image_cache/`, `hooks/`, `pairing/`, `sandboxes/`, `bin/`

### Pending
- Changes are staged but **not committed**
- Run `git commit` when ready
