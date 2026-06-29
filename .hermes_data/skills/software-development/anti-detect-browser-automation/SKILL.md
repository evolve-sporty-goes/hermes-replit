---
name: anti-detect-browser-automation
description: |
  Browser automation for signup/login flows using Playwright + system Chromium.
  Covers persistent-context launch patterns, proxy injection, Cloudflare
  Turnstile handling, and common pitfalls when automating bot-sensitive
  sites. Previously covered Camoufox (Firefox) — see migration note below.
version: 2.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [playwright, chromium, browser-automation, bot-detection, signup-automation]
    category: software-development
    related_skills: [computer-use]
---

# Browser Automation (Playwright + Chromium)

## Migration note (2026-06-29)

This workspace **migrated from Camoufox (Firefox) to Playwright + system Chromium** on Replit/NixOS.
Camoufox (anti-fingerprint Firefox wrapper) was removed because:
1. The `isMobile` CDP protocol error kept returning after every `pip install --upgrade playwright`
2. The Camoufox binary download (~700MB) was heavy and slow on ephemeral containers
3. System Chromium (already installed at `/nix/store/*-chromium-*/bin/chromium`) provides the same Playwright API without the compatibility layer

See `references/camoufox-playwright-cdp-compat.md` for the historical Camoufox notes including the `isMobile` patch.

## Current approach: Playwright + system Chromium

All signup/login scripts now use Playwright's `launch_persistent_context` with the system Chromium binary:

```python
from playwright.sync_api import sync_playwright

CHROMIUM_PATH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        user_data_dir,          # tmpdir per run (cleaned up on exit)
        executable_path=CHROMIUM_PATH,
        headless=False,
        proxy={"server": "socks5://..."},  # optional
    )
    page = context.pages[0] if context.pages else context.new_page()
    page.goto("https://example.com")
    # ... interact ...
```

### Key parameters

| Parameter | Purpose |
|---|---|
| `user_data_dir` | Fresh tmpdir per run (or persistent profile for session-keeping) |
| `executable_path=CHROMIUM_PATH` | Required on Replit/NixOS — system Chromium not auto-detected |
| `headless=False` | Required for Cloudflare Turnstile sites |
| `proxy={"server": "socks5://..."}` | Per-browser SOCKS5/HTTP proxy |
| `no_viewport=True` | Skip viewport sizing (Proton Mail needs this) |

### Script patterns in this workspace

**Pattern A — Fresh profile per run (signup scripts like openrouter_signup.py, firecrawl_gen.py):**
```python
import tempfile, shutil, atexit
browser_tmpdir = tempfile.mkdtemp(prefix="browser-profile-")
atexit.register(lambda: shutil.rmtree(browser_tmpdir, ignore_errors=True))

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        browser_tmpdir,
        executable_path=CHROMIUM_PATH,
        headless=False,
    )
    page = context.pages[0] if context.pages else context.new_page()
    # signup → verify → extract key all within one context
```

**Pattern B — Persistent profile (Proton Mail at ~/proton_profile):**
```python
with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        PROTON_PROFILE,
        executable_path=CHROMIUM_PATH,
        headless=False,
        no_viewport=True,
    )
    page = context.pages[0] if context.pages else context.new_page()
    # Already logged in from prior run
```

**Pattern C — Proxy rotation (torbox-signup.sh):**
```python
proxy_config = {"server": f"socks5://{proxy_addr}"} if proxy_addr else None
context = p.chromium.launch_persistent_context(
    td,
    executable_path=CHROMIUM,
    headless=False,
    proxy=proxy_config,
)
```

## Cloudflare handling

Most signup targets (OpenRouter, Firecrawl, TorBox) use Cloudflare Turnstile. Patterns:

### Passive wait (Camoufox auto-solved, Chromium needs manual handling)
```python
def cf_solved(page):
    """Check if page is past Cloudflare."""
    try:
        title = page.title()
        if "Just a moment" in title or "Checking" in title:
            return False
    except:
        pass
    try:
        if page.locator("iframe[src*='challenges.cloudflare.com']").is_visible(timeout=1000):
            return False
    except:
        pass
    return True

def wait_for_cf(page, timeout=15):
    for _ in range(timeout):
        if cf_solved(page):
            return True
        page.wait_for_timeout(1000)
    return False

def handle_cf_turnstile(page):
    """Click Cloudflare Turnstile checkbox if present."""
    for fr in page.frames:
        if "challenges.cloudflare" in fr.url or "cloudflare" in fr.name.lower():
            try:
                checkbox = fr.locator("input[type='checkbox'], .ctp-checkbox, #challenge-stage")
                if checkbox.first.is_visible(timeout=2000):
                    checkbox.first.click()
                    page.wait_for_timeout(5000)
                    return True
            except:
                pass
    return False
```

## Deep conversion pitfalls (Camoufox → Playwright)

1. **`Camoufox()` → `sync_playwright() + chromium.launch_persistent_context()`**: The old `with Camoufox(...) as browser: page = browser.new_page()` pattern maps to `with sync_playwright() as p: context = p.chromium.launch_persistent_context(...); page = context.pages[0] or context.new_page()`
2. **No `geoip=True`**: Playwright Chromium doesn't auto-derive timezone/locale from IP. If needed, set via context options.
3. **No `humanize=True`**: Playwright Chromium doesn't add human-like mouse jitter. Add manually if needed.
4. **`enable_cache=True`**: Not a Playwright option. Use `launch_persistent_context` for caching.
5. **`executable_path` is mandatory** on Replit/NixOS because Playwright's bundled Chromium isn't in the Nix store system path.
6. **`context.close()`** at the end of the `with sync_playwright()` block — the `with` block handles `p.stop()` but not `context.close()` explicitly if you exit early with `return`.

## When browser scripts break: diagnostic checklist

1. **Syntax check**: `bash -n script.sh` / `python3 -m py_compile script.py`
2. **Chromium path exists**: `ls /nix/store/*/bin/chromium`
3. **Playwright installed**: `python3 -c "from playwright.sync_api import sync_playwright; print('OK')"`
4. **Test minimal context**: `sync_playwright() → launch_persistent_context → new_page → goto example.com`
5. **Proxy dead?**: `socksocket().connect(("target.app", 443))` test before launching browser
6. **Cloudflare issue?**: Check title for "Just a moment", check for CF iframe

## Support files

- `references/camoufox-playwright-cdp-compat.md` — historical Camoufox notes and the `isMobile` CDP patch
- `scripts/patch-playwright-cdp.sh` — kept for reference but NOT needed after migration to Chromium
