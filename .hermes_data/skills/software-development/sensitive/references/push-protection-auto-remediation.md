# GitHub Push Protection — Auto-Remediation (REMOVED in v3)

**Status: Auto-remediation was REMOVED in the v3 sync rewrite (2026-06-29).** History rewrite is now a manual, explicit operation — never auto-triggered from a sync loop. This document is retained for reference when manually resolving push protection blocks.

## Current Behavior (v3)

If `git push` is rejected by GitHub secret scanning, the sync script simply reports `WARN: push failed` and exits. The user must manually:
1. Identify the blocked files from the error output
2. Add them to `.gitignore` sensitive block
3. Run `git filter-repo` to strip from history (see `references/push-protection-history-rewrite.md`)
4. Force-push

## Why Auto-Remediation Was Removed

1. **Force-push danger** — auto force-pushing rewritten history is destructive and should require human confirmation
2. **filter-repo removes `origin`** — re-adding it with correct auth in an error handler is fragile
3. **Scope creep** — sync should sync, not rewrite history
4. **User preference** — keep the script short and predictable

## Manual Resolution Workflow

See `references/push-protection-history-rewrite.md` for the full manual workflow.

## Parsing Logic (for manual use)

GitHub push protection error format:
```
remote: —— Cloudflare Account API Token ——————————————————————
remote:   - commit: 0b81e934e2aa3b6edc866100ecce6865dedf0e76
remote:     path: scripts/setup_cloudflare.sh:13
```

The regex `grep -oP 'path:\s+\K\S+'` extracts `scripts/setup_cloudflare.sh:13`, then `cut -d: -f1` gives `scripts/setup_cloudflare.sh`.

See also: `references/push-protection-history-rewrite.md` for the full `git filter-repo` workflow including the origin/auth pitfall.
See also: `references/sync-gitignore-integration.md` for how `scripts/sync` reads `.gitignore` and resolves bare directory/file names to full paths.
