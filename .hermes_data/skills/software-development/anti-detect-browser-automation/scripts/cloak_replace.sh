#!/bin/bash
# Replace playwright → cloakbrowser in all workspace scripts
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

  # 2. Remove `with sync_playwright() as p:` lines
  sed -i '/^with sync_playwright() as p:$/d' "$f"
  sed -i '/^[[:space:]]*with sync_playwright() as p:$/d' "$f"

  # 3. p.chromium.launch_persistent_context → launch_persistent_context
  sed -i 's/p\.chromium\.launch_persistent_context/launch_persistent_context/g' "$f"

  # 4. Remove executable_path=... lines
  sed -i '/executable_path=/d' "$f"

  # 5. Add humanize=True to launch_persistent_context calls
  sed -i 's/launch_persistent_context(\([^,)]*\), headless=False/launch_persistent_context(\1, headless=False, humanize=True/g' "$f"
  sed -i 's/launch_persistent_context(\([^,)]*\))$/launch_persistent_context(\1, humanize=True)/g' "$f"

  # 6. Remove p.stop()
  sed -i '/p\.stop()/d' "$f"

  echo "✓ $f"
done

echo ""
echo "Done. Backups saved as *.bak"
echo "NOTE: You still need to manually un-indent the block that was inside 'with sync_playwright()' — sed can't do this reliably."
echo "Run scripts with: xvfb-run python3 scripts/SCRIPT.py"
