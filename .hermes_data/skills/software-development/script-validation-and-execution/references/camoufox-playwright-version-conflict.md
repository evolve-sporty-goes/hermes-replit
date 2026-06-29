# Case: Camoufox 0.4.11 + Playwright 1.61.0 viewport protocol error

Date: 2026-06-29

## What happened

User ran `scripts/backup.sh` (TorBox signup) which chains to `scripts/email.sh`. The email script installs `camoufox[geoip]` and `playwright` via pip, then calls `duckmail.py` which uses `Camoufox()` browser context.

The browser launched but `browser.new_page()` failed with:

```
playwright._impl._errors.Error: Browser.new_page: Protocol error (Browser.setDefaultViewport): 
ERROR: failed to call method 'Browser.setDefaultViewport' with parameters {...}
Found property "<root>.viewport.isMobile" - false which is not described in this scheme
```

## Root cause

Camoufox 0.4.11 fetches a Chromium binary (v135.0.1-beta.24) whose CDP protocol doesn't match what Playwright 1.61.0 expects. The `isMobile` property in the `viewport` schema is the breaking difference.

## Fix options

1. **Pin compatible camoufox version**: `pip install camoufox==0.4.6` (known to work with Playwright ~1.52)
2. **Use system Chromium directly**: Replace `Camoufox()` with `playwright.chromium.launch()` using the system's `/nix/store/.../chromium` binary
3. **Bypass browser entirely**: For TorBox signup, the API may accept direct `curl` calls without browser verification

## Lesson

When a script auto-installs browser automation deps, version mismatches between the browser binary and the Playwright/camoufox library are likely. Prefer pinning known-good versions or using system Chromium directly in NixOS environments.

## Environment note

On Replit NixOS, Chromium is available at:
```
/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium
```
