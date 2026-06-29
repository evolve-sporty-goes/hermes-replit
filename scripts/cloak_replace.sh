#!/bin/bash
# Replace playwright → cloakbrowser in all scripts
# Usage: bash scripts/cloak_replace.sh

set -e

FILES=(
  scripts/torbox-full-tor-signup.sh
  scripts/torbox-full-signup.sh
  scripts/torbox-signup.sh
  scripts/magiclink.sh
  scripts/backup.sh
  scripts/firecrawl_gen.py
)

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  cp "$f" "$f.bak"

  # 1. Import
  sed -i 's/^from playwright\.sync_api import sync_playwright$/from cloakbrowser import launch, launch_persistent_context/' "$f"

  # 2. Remove `` lines
  sed -i '/^$/d' "$f"
  sed -i '/^[[:space:]]*$/d' "$f"

  # 3. launch_persistent_context → launch_persistent_context
  sed -i 's/p\.chromium\.launch_persistent_context/launch_persistent_context/g' "$f"


  # 5. Add humanize=True to launch_persistent_context calls
  sed -i 's/launch_persistent_context(\([^,)]*\), headless=False/launch_persistent_context(\1, headless=False, humanize=True/g' "$f", humanize=True
  sed -i 's/launch_persistent_context(\([^,)]*\))$/launch_persistent_context(\1, humanize=True)/g' "$f"

  # 6. Remove p.stop()
  sed -i '/p\.stop()/d' "$f"

  echo "✓ $f"
done

echo ""
echo "Done. Backups saved as *.bak"
echo "Run scripts with: xvfb-run python3 scripts/SCRIPT.py"
