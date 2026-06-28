# Replit Workspace Reorganization — Session Example

## What Was Done

Moved scattered root-level files into logical directories:

| Old Location | New Location |
|---|---|
| `email.sh` | `scripts/email.sh` |
| `script.sh`, `sync.sh`, `hermes.sh` | `scripts/` |
| `firecrawl_gen.py`, `openrouter_signup.py` | `scripts/` |
| `torbox-*.sh`, `tor_signup.sh`, `Signup`, `backup.sh` | `scripts/` |
| `magiclink.sh`, `start-tor-flare.sh`, `flaresolverr-*` | `scripts/` |
| `brave`, `firefox`, `torbrowser` | `scripts/` |
| `openrouter_credentials.txt`, `firecrawl_credentials.txt`, `torbox_credentials.txt`, `.pat`, `.supabase_anon_key`, `mail.txt` | `credentials/` |
| `Instructions.txt`, `torbox-info.md` | `docs/` |
| `subnet-proxy/` | kept at root (standalone Go project) |

## Path Updates Required in Scripts

Every script that hardcoded `/home/runner/workspace/<filename>` had to be updated to `/home/runner/workspace/scripts/<filename>` or `/home/runner/workspace/credentials/<filename>`.

### Chain Effect

`email.sh` writes to `mail.txt` — when `mail.txt` moved to `credentials/`, the reference in `email.sh` (which lives at `scripts/email.sh`) needed updating to the full absolute path since it uses relative `mail.txt` from its execution context.

### sensitive.txt

This file lists paths that `sync.sh` iterates over to sync to the hermes-secrets repo. ALL paths must be updated when files move, since `sync.sh` reads them as `/home/runner/workspace/<path>`.

## Verification Pattern

After moving files, use `search_files()` to scan all scripts for each old path. A verification script (run via `execute_code`) should:

1. Check old path NOT in file content (with substring awareness)
2. Check new path IS in file content
3. Check all files in `sensitive.txt` exist on disk
4. Check all expected files exist at new locations

See `scripts/` for an actual verification script template (cleaned up after run).
