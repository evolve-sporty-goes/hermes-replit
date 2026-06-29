---
name: script-validation-and-execution
description: Validate, inspect, and safely execute user scripts in the workspace. Distinguish safe health checks from destructive or external-service automation.
trigger: running scripts, checking scripts, executing .sh/.py files, validating script health, scripts folder, backup.sh, signup scripts
version: 1
---

# Script Validation and Execution

Validate, inspect, and safely execute user scripts in `/home/runner/workspace/scripts/` (or equivalent workspace `scripts/` directory). This skill assumes scripts may include credential access, external API calls, browser automation, and account signup flows.

## First Rule: Inspect Before Executing

Never run a script blindly when the user says "run all scripts" or "run it". Always read and classify first.

1. List the scripts directory
2. Read the target script(s)
3. Syntax-check shell/Python files
4. Classify risk:
   - **Safe to run dry**: no network, no credentials, no writes outside `/tmp`
   - **Safe to run with care**: local-only, reads own credentials but only writes to known files
   - **Do not run without explicit confirmation**: external signup APIs, email automation, Proton/Discord/Telegram integrations, Tor/FlareSolvers, Chromium automation, account rotation

## Classifying Script Contents

Look for these markers to determine safety:

| Marker | Risk | Example |
|--------|------|---------|
| `curl` to third-party auth/signup endpoints | **High — external account creation** | `db.torbox.app/auth/v1/signup` |
| Playwright/Selenium/Chromium automation | **High — browser automation with user credentials** | `playwright.sync_api`, `launch_persistent_context` |
| `set -euo pipefail` | Low — good practice | shell safety |
| Reads `~/config.py` for creds | Medium — touches user secrets | `import config; C.PROTON_USERNAME` |
| Writes `*_credentials.txt` | Medium — credential file mutation | `echo email=... >> torbox_credentials.txt` |
| Tor/FlareSolverr/proxy rotation | High — network infra automation | `flaresolverr-proxy.sh`, `start-tor-flare.sh` |
| `bash email.sh` chain calls | Inspect the full chain | signup scripts often delegate to helper scripts |
| Misleading filename | Inspect contents | `backup.sh` contained TorBox signup, not backups |

## Initial Safety Checks (always run these first)

### List scripts directory
```bash
ls -la /home/runner/workspace/scripts/
```

### Syntax check shell scripts
```bash
for f in /home/runner/workspace/scripts/*.sh; do
  echo "=== $f ==="
  bash -n "$f" && echo OK || echo FAIL
done
```

### Syntax check Python scripts
```bash
for f in /home/runner/workspace/scripts/*.py; do
  echo "=== $f ==="
  python3 -m py_compile "$f" && echo OK || echo FAIL
done
```

### Identify interpreter and shebang
```bash
file /home/runner/workspace/scripts/<name>
head -1 /home/runner/workspace/scripts/<name>
```

## Risk Responses

### Safe scripts (e.g., local reports, setup helpers)
Run directly after the user confirms.

```bash
bash /home/runner/workspace/scripts/<name>.sh
python3 /home/runner/workspace/scripts/<name>.py
```

### Credential-reading but non-destructive scripts
Run only after confirming the user wants it. State what it will read and write.

```bash
# Example: this reads ~/config.py, calls one external API, writes one credential file
bash /home/runner/workspace/scripts/<name>.sh
```

### Account-signup / external-service / browser automation scripts
**Do not run without explicit per-script confirmation.** Explain:
- what external service it touches
- what credentials it reads
- what side effects it causes (new accounts, emails sent, proxy rotation)

Offer alternatives:
1. Dry-run / inspect mode if the script supports it
2. Syntax and reference checks only
3. Run one step manually with substituted test values
4. Run the full script only after the user explicitly says "run <filename>"

## Common Pitfall: Mislabeled Scripts

Scripts may not match their filenames. Example: `backup.sh` contained a TorBox signup workflow. Always read the shebang and first few lines before assuming purpose.

Verification habit:
```bash
# shebang + first 20 lines + grep for keywords
head -20 /home/runner/workspace/scripts/<name>
grep -E 'curl|signup|proton|playwright|firefox|chromium|tor|flare|email' /home/runner/workspace/scripts/<name>
```

## Common Pitfall: Chained Helper Scripts

A script may call others (e.g., `bash /home/runner/workspace/scripts/email.sh`). Inspect the full chain before running. A top-level script that looks harmless may delegate to a destructive helper.

```bash
grep -R "bash .*scripts/\|source .*scripts/\|/home/runner/workspace/scripts/" /home/runner/workspace/scripts/
```

## User Style Note

This user prefers terse commands and explicit scripts they execute themselves. When in doubt, provide the command and let them run it.

## Session References

- `references/backup-sh-mislabel-case.md` — example of a script whose filename (`backup.sh`) concealed a TorBox signup + Proton Mail browser-automation workflow.

## Related Skills

- **`workspace-organization`** — for moving scripts into `scripts/` and updating path references afterward
- **`sensitive`** — for scanning scripts and credential files for secrets and keeping `.gitignore` in sync
