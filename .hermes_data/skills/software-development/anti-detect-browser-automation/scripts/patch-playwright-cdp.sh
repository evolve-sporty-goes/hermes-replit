#!/usr/bin/env bash
# Remove isMobile from Playwright's Browser.setDefaultViewport CDP call.
# Required for Camoufox (Firefox CDP rejects isMobile).
# Re-run after every `pip install --upgrade playwright`.

set -euo pipefail

JS_FILE=$(python3 -c "import playwright; print(playwright.__path__[0])")/driver/package/lib/coreBundle.js

if [ ! -f "$JS_FILE" ]; then
  echo "ERROR: coreBundle.js not found at $JS_FILE" >&2
  exit 1
fi

if grep -q 'isMobile: !!this._options.isMobile' "$JS_FILE"; then
  sed -i '/          isMobile: !!this._options.isMobile/d' "$JS_FILE"
  echo "Patched: removed isMobile from $JS_FILE"
else
  echo "Already patched: isMobile not found in viewport object"
fi
