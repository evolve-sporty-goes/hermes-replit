#!/bin/bash
# One-liner: replace playwright → cloakbrowser in all workspace scripts
# Usage: bash scripts/cloak_replace.sh

grep -rl 'sync_playwright' scripts/ | xargs sed -i \
  's/from playwright.sync_api import sync_playwright/from cloakbrowser import launch, launch_persistent_context/g;
   s/p\.chromium\.launch_persistent_context/launch_persistent_context/g;
   /^with sync_playwright() as p:$/d;
   /executable_path=/d;
   s/headless=False,/headless=False, humanize=True,/g'

echo "Done. NOTE: body inside former 'with sync_playwright()' blocks needs manual un-indent."
