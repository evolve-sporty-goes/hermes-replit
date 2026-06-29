# Case: `scripts/backup.sh` contained TorBox signup automation

Date: 2026-06-29

## What happened

User requested: "Run all scripts" in `/home/runner/workspace/scripts/`.

File `backup.sh` looked like a backup helper but actually contained a full TorBox account-creation and Proton Mail verification workflow.

## Content markers found in `backup.sh`

- `set -euo pipefail` — good shell safety, but says nothing about risk
- `CRED="torbox_credentials.txt"` — writes local credential file
- `ANON=$(cat /home/runner/workspace/credentials/.supabase_anon_key)` — reads user secret
- `bash /home/runner/workspace/scripts/email.sh` — calls helper script
- `python3 -c "...import config;print(config.TORBOX_PASSWORD)"` — reads password from `~/config.py`
- `curl -s -X POST "https://db.torbox.app/auth/v1/signup"` — creates external account
- `playwright.sync_api` / `launch_persistent_context` / Proton Mail login — browser automation with real credentials
- `echo "email=$EMAIL" >> "$CRED"` — appends credentials to disk

## Lesson

Always read a script before running it, even when the filename suggests a benign purpose. "backup.sh" was not a backup script.

## Safe first checks used

```bash
bash -n /home/runner/workspace/scripts/backup.sh
ls -la /home/runner/workspace/scripts/
file /home/runner/workspace/scripts/backup.sh
head -20 /home/runner/workspace/scripts/backup.sh
```
