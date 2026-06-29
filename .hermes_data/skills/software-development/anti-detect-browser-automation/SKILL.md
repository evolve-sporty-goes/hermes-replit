---
name: anti-detect-browser-automation
description: |
  Anti-detect browser automation with Camoufox + Playwright (Firefox).
  Covers Camoufox setup, the isMobile CDP protocol incompatibility fix,
  fingerprint-aware browser launching, and patterns for programmatic
  login/form-fill flows without human interaction. Use when the task
  involves automating websites that employ bot detection, fingerprinting,
  or when the user's existing Camoufox/Playwright scripts break on the
  setDefaultViewport protocol error.
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [camoufox, playwright, firefox, anti-detect, browser-automation, bot-detection, fingerprint]
    category: software-development
    related_skills: [computer-use]
---

# Anti-Detect Browser Automation (Camoufox + Playwright)

Camoufox is a Firefox-based anti-detection browser that wraps Playwright.
It patches Firefox to resist fingerprinting (canvas noise, audio seed,
WebRTC leak blocking, TLS/JA3 spoofing, etc.) while exposing the familiar
Playwright API via `from camoufox.sync_api import Camoufox`.

## When to use

- Automating signups/logins on sites with bot detection (Cloudflare Turnstile,
  DataDome, PerimeterX, etc.)
- Tasks where the user already has Camoufox-based scripts
- Browser automation where headless Chromium would get flagged but a
  real Firefox-engine browser with forged fingerprints would not

## Core usage pattern

```python
from camoufox.sync_api import Camoufox

with Camoufox(headless=True) as browser:
    context = browser.new_context(viewport={"width": 1280, "height": 720})
    page = context.new_page()
    page.goto("https://example.com")
    # ... interact ...
    browser.close()
```

Or using the higher-level `NewContext` helper to get a fresh fingerprint
identity per context:

```python
from camoufox.sync_api import Camoufox, NewContext

with Camoufox(headless=True) as browser:
    context = NewContext(browser, os="windows")  # optional OS targeting
    page = context.new_page()
    # ...
```

## Known issues & fixes

### IsMobile CDP protocol incompatibility (CRITICAL)

**Symptom:** `Browser.setDefaultViewport` protocol error — Playwright sends
`isMobile` in the viewport object, but Firefox's CDP doesn't recognize it:

```
Protocol error (Browser.setDefaultViewport): ERROR: failed to call method
'Browser.setDefaultViewport' with parameters {..., "viewport": {
  "viewportSize": {...}, "deviceScaleFactor": 1, "isMobile": false
}} Found property "<root>.viewport.isMobile" - false which is not described
in this scheme
```

**Root cause:** Newer Playwright versions (1.50+) include `isMobile: false`
in the `Browser.setDefaultViewport` CDP call. Firefox's CDP server rejects
unknown properties. Camoufox inherits Firefox's CDP, so it breaks on
`new_context()` and `new_page()`.

** `isMobile` from Playwright's bundled `coreBundle.js`:

```bash
# Find the exact file
JS_FILE=$(python3 -c "import playwright; print(playwright.__path__[0])")/driver/package/lib/coreBundle.js

# Patch: remove isMobile from the viewport object in doUpdateDefaultViewport
sed -i 's/          deviceScaleFactor: this._options.deviceScaleFactor || 1,\n          isMobile: !!this._options.isMobile//' "$JS_FILE"
```

Or apply as a one-liner Python patch:

```python
import re, pathlib
js = pathlib.Path("/path/to/coreBundle.js").read_text()
js = re.sub(
    r'(deviceScaleFactor: this\._options\.deviceScaleFactor \|\| 1),?\s*\n\s*isMobile: !!this\._options\.isMobile',
    r'\1',
    js
)
pathlib.Path("/path/to/coreBundle.js").write_text(js)
```

**Another symptom:** `Skipping unknown patch audio:seed` / `Skipping unknown
patch canvas:seed` lines in stderr — these are **harmless**. They appear
when Camoufox's fingerprint patches target browser internals that shifted
between versions. They don't break automation.

### Camoufox Not Installed (first run)

**Symptom:** `CamoufoxNotInstalled: official/stable is not installed`

**Fix:**
```bash
python3 -m camoufox fetch
```
Downloads ~700 MB browser binary + UBO addon + MaxMind GeoLite2 DBs.

### Camoufox version compatibility

- `camoufox` (PyPI, daijro) → older, stuck at 0.4.11 — has the viewport bug
- `cloverlabs-camoufox` (PyPI, maintained fork) → active, uses same `camoufox`
  Python namespace, ships newer Firefox builds (v135+)

Migration:
```bash
pip uninstall camoufox -y
pip install cloverlabs-camoufox
python3 -m camoufox fetch  # re-downloads browser binary
```

The Python import stays `from camoufox.sync_api import Camoufox` regardless
of which PyPI package is installed — only the binary differs.

## Camoufox launch options (commonly used)

| Option | Purpose |
|---|---|
| `headless=True/False` | Run headless |
| `os="windows"/"macos"/"linux"` | Target OS for fingerprint |
| `block_webrtc=True` | Prevent WebRTC IP leaks |
| `block_images=True` | Speed up page loads |
| `geoip=True` | Auto-derive timezone/locale from exit IP |
| `humanize=True` | Add human-like mouse movement jitter |
| `proxy={"server": ...}` | Per-browser proxy |
| `window=(W, H)` | Custom outer window size |
| `noViewport=True` | Skip viewport (but CDP patch needed anyway) |
| `exclude_addons=[...]` | Disable default addons (e.g., UBO) |
| `locale="en-US"` | Accept-language header |

## Debugging protocol errors

When debugging Camoufox/Playwright issues, the protocol layer is where
things break — not the Python code. Diagnostic steps:

1. **Verify browser binary:** `python3 -m camoufox fetch`
2. **Test minimal context:** `browser.new_context(viewport={"width":1280,"height":720})` then `new_page()`
3. **Check coreBundle.js patch:** grep for `isMobile` in the bundled JS — if present, patch it
4. **Separate concerns:** "Skipping unknown patch" lines are noise; protocol errors are the real failure

Note: In newer cloverlabs-camoufox versions, the CDP incompatibility may
be resolved upstream. Check release notes before applying the coreBundle.js
patch.
