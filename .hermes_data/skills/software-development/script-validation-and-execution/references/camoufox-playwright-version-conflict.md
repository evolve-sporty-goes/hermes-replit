# Case: Camoufox → full Playwright Chromium migration

Date: 2026-06-29

## What happened

User ran `scripts/backup.sh` (TorBox signup) which chains to `scripts/email.sh`. The email script installed `camoufox` + `playwright` via pip, then called `duckmail.py` which used `Camoufox()`.

The browser launched but `browser.new_page()` failed with:

```
playwright._impl._errors.Error: Browser.new_page: Protocol error (Browser.setDefaultViewport): 
ERROR: failed to call method 'Browser.setDefaultViewport' with parameters {...}
Found property "<root>.viewport.isMobile" - false which is not described in this scheme
```

## Root cause

Camoufox (Firefox-based anti-detection browser) wraps Playwright but inherits Firefox's CDP server which rejects `isMobile` in `Browser.setDefaultViewport`. Newer Playwright versions (1.50+) always include `isMobile: false`, causing the breakage. The bug returned on every `pip install --upgrade playwright`.

## Resolution (full migration)

Instead of patching coreBundle.js after every Playwright upgrade, **all Camoufox scripts were converted to Playwright + system Chromium**:

- `email.sh` → `duckmail.py` uses `sync_playwright() → chromium.launch()`
- `openrouter_signup.py` → uses `launch_persistent_context(tmpdir, executable_path=CHROMIUM_PATH)`
- `firecrawl_gen.py` → same pattern
- `torbox-camoufox-signup.sh` → renamed to `torbox-signup.sh`, uses Playwright in embedded Python

Camoufox package was uninstalled.

## Pattern used everywhere

```python
from playwright.sync_api import sync_playwright

CHROMIUM_PATH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        user_data_dir,
        executable_path=CHROMIUM_PATH,
        headless=False,
    )
    page = context.pages[0] if context.pages else context.new_page()
```

## Lesson

When a recurring CDP incompatibility keeps returning after package upgrades, switch to the vanilla tool (Playwright + system Chromium) rather than maintaining a wrapper (Camoufox) that breaks on every upstream change.

## Environment note

On Replit NixOS, Chromium is at:
```
/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium
```
Use `executable_path=` — Playwright won't auto-detect Nix store binaries.
