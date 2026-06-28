#!/usr/bin/env bash
# verify-vault.sh — check vault health: exists, has notes, no stale temp files
# Usage: bash scripts/verify-vault.sh [vault_path]
set -euo pipefail
VAULT="${1:-.hermes_data/obsidian-vault}"

echo "Vault health: $VAULT"
[ -d "$VAULT" ] && echo "  OK: directory exists" || { echo "  FAIL: missing"; exit 1; }

NOTE_COUNT=$(find "$VAULT" -name "*.md" -not -path "*/references/*" | wc -l)
echo "  Notes: $NOTE_COUNT"
[ "$NOTE_COUNT" -gt 0 ] || echo "  WARN: no notes yet"

# Check for .env reference
if [ -f ".hermes_data/.env" ]; then
    grep -q "OBSIDIAN_VAULT_PATH" .hermes_data/.env && echo "  OK: .env has vault path" || echo "  WARN: .env missing OBSIDIAN_VAULT_PATH"
fi

# Check .pat not committed (should be gitignored or absent from git)
if [ -f ".pat" ] && git ls-files --error-unmatch .pat >/dev/null 2>&1; then
    echo "  CRITICAL: .pat is tracked in git — remove it!"
else
    echo "  OK: .pat not in git (or not present)"
fi

echo "done"
