# Proton Mail Chromium Workaround

## Problem

Camoufox's Firefox Juggler driver crashes when navigating to any proton.me page (login, inbox, settings). The error is:

```
TypeError: Cannot read properties of undefined (reading 'url')
    at FFBrowserContext.<anonymous> (.../playwright/driver/package/lib/coreBundle.js:49624:39)
```

This happens because Proton Mail's JS triggers an uncaught error where `pageError.location` is undefined, and the Juggler handler tries to access `pageError.location.url` without guarding it.

## coreBundle.js Patch (Fix the Crash at Source)

You can patch Playwright's Node.js driver to guard `pageError.location` before accessing its properties. This prevents the crash in BOTH Camoufox and vanilla Playwright Firefox:

```bash
COREBUNDLE="$(python3 -c 'import playwright; print(playwright.__path__[0])')/driver/package/lib/coreBundle.js"

# Guard all three properties accessed from pageError.location
sed -i 's/url: pageError\.location\.url/url: (pageError.location \&\& pageError.location.url) || ""/g' "$COREBUNDLE"
sed -i 's/line: pageError\.location\.lineNumber/line: (pageError.location \&\& pageError.location.lineNumber) || 0/g' "$COREBUNDLE"
sed -i 's/column: pageError\.location\.columnNumber/column: (pageError.location \&\& pageError.location.columnNumber) || 0/g' "$COREBUNDLE"
```

After patching, Camoufox can navigate Proton Mail without crashing. However, even with the patch, some Proton pages still cause an EPIPE error on exit (non-fatal — the process completes). The patch persists across sessions until Playwright is reinstalled/updated.

**Note:** If the patch doesn't fully resolve the crash (EPIPE on exit, or other Firefox-specific issues), fall back to the Chromium subprocess pattern below.

## Affected Scenarios

- Logging into Proton Mail (account.proton.me/login)
- Accessing the inbox (mail.proton.me/u/0/inbox)
- Any proton.me subpage

## Workaround: System Chromium (Subprocess Pattern)

When the coreBundle patch isn't sufficient, use Playwright with system Chromium via a **subprocess** — not inline in the same Camoufox session. Running Chromium inside the same Python process as Camoufox causes an `asyncio event-loop conflict`:

```
playwright._impl._errors.Error: It looks like you are using Playwright Sync API inside the asyncio loop.
Please use the Async API instead.
```

### Subprocess Pattern

Write the Proton Mail logic as an inline Python script string, then execute it via `subprocess.run`:

```python
import subprocess, sys

PROTON_FETCH_SCRIPT = r'''
import sys, os, re
from playwright.sync_api import sync_playwright

PROTON_USER = sys.argv[1]
PROTON_PASS = sys.argv[2]
CHROMIUM = sys.argv[3]
PROFILE_DIR = sys.argv[4]
SEARCH_EMAIL = sys.argv[5]

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        PROFILE_DIR,
        executable_path=CHROMIUM,
        headless=False,
        no_viewport=True,
    )
    page = context.pages[0] if context.pages else context.new_page()

    # Login (or skip if already logged in)
    page.goto("https://account.proton.me/login", timeout=60000)
    page.wait_for_timeout(3000)

    try:
        if page.locator("a:has-text('Mail')").is_visible(timeout=3000):
            print("Already logged in — skipping credentials")
        else:
            raise Exception("Not logged in")
    except:
        page.locator("#username").fill(PROTON_USER)
        page.locator("#password").fill(PROTON_PASS)
        page.locator("button[type='submit']").click()
        page.wait_for_timeout(10000)

    # Navigate to inbox
    page.locator("a:has-text('Mail')").first.click(timeout=0)
    page.wait_for_timeout(5000)

    # Search inbox using / shortcut
    page.keyboard.press("/")
    page.wait_for_timeout(1000)
    page.keyboard.type(SEARCH_EMAIL, delay=50)
    page.keyboard.press("Enter")
    page.wait_for_timeout(5000)

    # Click first result
    page.locator(".item-container").first.click()
    page.wait_for_timeout(5000)

    # Extract verification link from frames
    verify_url = None
    for frame in page.frames:
        try:
            html = frame.content()
            if "verify" in html.lower() or "confirm" in html.lower():
                matches = re.findall(r'https://[^\s"\'<>]*(?:verify|confirm)[^\s"\'<>]*', html)
                if matches:
                    verify_url = matches[0].replace("&amp;", "&")
                    break
        except:
            pass

    context.close()

if verify_url:
    print("VERIFY_URL:" + verify_url)
else:
    print("VERIFY_URL:NOT_FOUND")
'''

result = subprocess.run(
    [sys.executable, "-c", PROTON_FETCH_SCRIPT, PROTON_USER, PROTON_PASS, CHROMIUM_PATH, PROFILE_DIR, signup_email],
    capture_output=True, text=True, timeout=180,
)

# Parse output
for line in result.stdout.strip().split("\n"):
    if line.startswith("VERIFY_URL:"):
        url = line[len("VERIFY_URL:"):]
        if url != "NOT_FOUND":
            return url
```

### Key Details

- **Must use `subprocess.run`** — importing `sync_playwright` in the same process as Camoufox causes event-loop conflict
- **`launch_persistent_context` with `~/proton_profile`** — preserves login state across runs
- **Proton search: `/` keyboard shortcut** — the search input (`data-testid="search-keyword"`) is `readonly` until activated; use `keyboard.press("/")` + `keyboard.type()`, NOT `.fill()`
- **`timeout=0` on "Mail" link click** — avoids hanging if the element is slow to respond
- **Login skip check** — if `a:has-text('Mail')` is visible, already logged in; skip credentials
- **Output via print()** — subprocess captures stdout; use a prefix like `VERIFY_URL:` for parsing

### Finding the Chromium Binary

On Nix/Replit environments, system Chromium is at:
```
/nix/store/<hash>-chromium-<version>/bin/chromium
```

Find the latest:
```bash
ls /nix/store/*chromium-1[3-9]*/bin/chromium 2>/dev/null | tail -1
```

## Why This Happens

Camoufox patches Firefox's Juggler protocol to give Playwright an isolated view of the page. Proton Mail's SPA triggers `pageError` events where `pageError.location` is undefined. The Juggler handler in `coreBundle.js` accesses `pageError.location.url` without guarding, causing a TypeError crash. Chromium uses CDP instead of Juggler and doesn't have this issue.

## Hybrid Approach

For workflows that need both anti-fingerprint (Camoufox) and Proton Mail access:

1. Use **Camoufox** for the main site (OpenRouter signup/signin, Firecrawl signup/signin)
2. Use **system Chromium via subprocess** (Playwright) for Proton Mail (email verification)
3. Pass data between sessions via subprocess stdout (e.g. `VERIFY_URL:<url>`)

This is the pattern used in both the Firecrawl and OpenRouter signup workflows.

## email.sh Subprocess Env

When calling `bash email.sh` from a Python subprocess, the env MUST be configured correctly or `duckmail.py` (which uses Camoufox) won't find its modules:

```python
venv_bin = os.path.dirname(sys.executable)
venv_dir = os.path.dirname(venv_bin)
pythonlibs = "/home/runner/workspace/.pythonlibs/lib/python3.12/site-packages"

result = subprocess.run(
    ["bash", "email.sh"],
    capture_output=True, text=True, timeout=120,
    env={**os.environ,
         "PYTHONPATH": pythonlibs + ":/home/runner:/home/runner/workspace",
         "PATH": venv_bin + ":" + os.environ.get("PATH", ""),
         "VIRTUAL_ENV": venv_dir}
)

# Capture email from stdout (last line with @)
email = [l.strip() for l in result.stdout.strip().split("\n") if "@" in l.strip()][-1]
```

Without these env vars, system `python3` resolves instead of venv python, and `camoufox` module (installed in `.pythonlibs`) is not found.
