---
name: sensitive-rules
description: Rules for identifying and handling sensitive/secret files in the workspace
version: 1.0.0
---

# Sensitive File Rules

## What counts as sensitive
- Files containing **hardcoded secrets** (passwords, API keys, tokens, bearer tokens, private keys)
- Only **literal values** in source code count — variables read from env/config at runtime do NOT
- Files that **indirectly run** a sensitive script are NOT themselves sensitive
- Email addresses in code or data files ARE sensitive (they identify accounts)
- `mail.txt` is NOT sensitive — it's a transient log of generated Duck emails, not account credentials
- **IGNORE email addresses found inside documentation, markdown, skill references, and example/template files** — only flag emails hardcoded in executable code (.py, .sh) or stored in data/credential output files
- Session dumps are NOT sensitive

## Scope
- Only files **inside `/home/runner/workspace/`** — nothing outside workspace
- Files outside workspace (e.g. `~/config.py`, `~/duckmail.py`) are excluded

## Format of sensitive.txt
- **Just file paths** — one per line, absolute paths
- No labels, no tiers, no descriptions, no comments, nothing else
- The user explicitly rejected severity tiers — bare paths only

## What to check
- `.py` and `.sh` files with hardcoded variables (PASSWORD, TOKEN, API_KEY, SECRET, BEARER, PRIVATE_KEY, CREDENTIAL) assigned to **literal string values**
- Email addresses hardcoded in code ARE sensitive
- Credential output files (e.g. `*_credentials.txt`) containing API keys
- Token/auth files (`.pat`, `auth.json`, `.env`)

## Runtime reference is NOT sensitive
```
# NOT sensitive — reads from config at runtime
PROTON_PASS = cfg.PROTON_PASSWORD
```

```
# SENSITIVE — hardcoded literal
PROTON_PASSWORD="Saty..."
```

## sync.sh integration
- `sync.sh` reads `sensitive.txt` dynamically via `while IFS= read -r` loop
- Do NOT hardcode sensitive file paths in sync.sh — read them from sensitive.txt
- Each path from sensitive.txt is synced to hermes-secrets repo using `basename` as the repo filename
- `.gitignore` is updated separately (see "Updating .gitignore" section below), not by sync.sh

## Behavioral Rules
- When listing sensitive files, output ONLY bare paths — user explicitly rejected tiers, labels, descriptions
- Files that call other sensitive scripts are NOT sensitive themselves (indirect execution doesn't count)

## Updating .gitignore

After any edit to `sensitive.txt`, also update `.gitignore` so sensitive files are excluded from the workspace git repo. Run:

```bash
# Remove old sensitive block from .gitignore
sed -i '/^# Sensitive files (from sensitive.txt)/,/^$/d' /home/runner/workspace/.gitignore

# Append fresh block with relative paths
(echo "# Sensitive files (from sensitive.txt)"; while IFS= read -r p; do
  [ -z "$p" ] && continue
  echo "${p#/home/runner/workspace/}"
done < /home/runner/workspace/sensitive.txt; echo "") >> /home/runner/workspace/.gitignore
```

This is the same logic `sync.sh` runs before git push — but run it immediately after editing `sensitive.txt` so files are ignored right away, not just at push time.

## Scanning for new sensitive files

Periodically scan the workspace for files containing hardcoded secrets that aren't yet in `sensitive.txt`. See `references/scanning-technique.md` for regex patterns, exclusions, and the sensitive-vs-runtime-ref distinction. See `references/verify-sensitive-txt.md` for the ad-hoc verification script to run after editing sensitive.txt.

## Purging committed sensitive files from history

When sensitive files were committed before being added to `.gitignore`, they remain in git history even though they're now ignored. Use `git-filter-repo` to purge them. See `references/purge-sensitive-from-git-history.md` for the full procedure (stop watcher → commit → filter-repo → re-add remote → force push → verify).
