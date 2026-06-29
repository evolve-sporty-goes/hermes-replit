---
name: anti-detect-browser-automation
description: |
  Browser automation for signup/login flows using CloakBrowser.
  Covers launch patterns, proxy injection, Cloudflare Turnstile auto-solve,
  humanize behavior, persistent profiles, and common pitfalls when
  automating bot-sensitive sites. CloakBrowser is a custom-compiled Chromium
  with 58+ C++ source-level stealth patches — passes 30/30 bot detection tests.
version: 4.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [playwright, chromium, browser-automation, bot-detection, signup-automation, cloakbrowser]
    category: software-development
    related_skills: [computer-use]
---

# Browser Automation (CloakBrowser)

## Migration history

1. **Camoufox (Firefox)** → removed 2026-06-29 (CDP `isMobile` errors, heavy binary).
2. **Vanilla Playwright + bundled Chromium** → replaced 2026-07-01 by CloakBrowser.
3. **CloakBrowser** (current) — custom-compiled Chromium with 58+ C++ source-level stealth patches. Passes 30/30 bot detection tests incl. Cloudflare Turnstile, FingerprintJS, reCAPTCHA v3 (0.9 score). Drop-in Playwright replacement.

See `references/camoufox-playwright-cdp-compat.md` for historical Camoufox/Playwright migration notes.

## Setup

```bash
pip install cloakbrowser
python3 -m cloakbrowser install      # Download stealth Chromium binary
python3 -m cloakbrowser info         # Check install status
```

## Current approach: CloakBrowser

CloakBrowser provides `launch()` and `launch_persistent_context()` as top-level
functions — no `sync_playwright()` context manager needed. Returns standard
Playwright objects; all Playwright methods work unchanged.

```python
from cloakbrowser import launch, launch_persistent_context

# Fresh profile per run
import tempfile, shutil, atexit
browser_tmpdir = tempfile.mkdtemp(prefix="browser-profile-")
atexit.register(lambda: shutil.rmtree(browser_tmpdir, ignore_errors=True))

context = launch_persistent_context(
    browser_tmpdir,
    headless=False,
    humanize=True,    # human-like mouse curves, keyboard timing, scroll patterns
    proxy="socks5://user:pass@proxy:1080",  # optional; inline credentials
    geoip=True,       # auto-set timezone/locale from proxy IP (requires proxy)
)
page = context.pages[0] if context.pages else context.new_page()
page.goto("https://example.com")
# ... interact ...
context.close()
```

### Key parameters

| Parameter | Purpose |
|---|---|
| `headless=False` | User preference for this workspace |
| `humanize=True` | Human-like mouse curves, keyboard timing, scroll patterns — one flag |
| `geoip=True` | Auto-derive timezone/locale from proxy IP (requires proxy) |
| `proxy="socks5://..."` | HTTP or SOCKS5 with inline credentials (string, not dict) |
| `license_key="cb_..."` | Pro tier (v148+ binaries). Free tier = v146 (goes stale within weeks) |

### API surface

CloakBrowser returns **standard Playwright objects** (`Browser`, `BrowserContext`, `Page`).

| CloakBrowser function | Old Playwright pattern |
|---|---|
| `launch(headless=False, humanize=True)` | `sync_playwright() → p.chromium.launch()` + manual JS injection + humanize helpers |
| `launch_persistent_context(dir, headless=False, humanize=True)` | `sync_playwright() → p.chromium.launch_persistent_context()` + manual JS injection |
| `humanize=True` | Was: custom `human_type()` / `human_click()` helper functions |
| `geoip=True` | Was: manual `timezone_id` / `locale` context options |
| `proxy="socks5://..."` (string) | Was: `proxy={"server": "socks5://..."}` (dict) |

### Script patterns in this workspace

**Pattern A — Fresh profile per run (openrouter_signup.py, firecrawl_gen.py):**
```python
from cloakbrowser import launch_persistent_context
import tempfile, shutil, atexit

browser_tmpdir = tempfile.mkdtemp(prefix="browser-profile-")
atexit.register(lambda: shutil.rmtree(browser_tmpdir, ignore_errors=True))

context = launch_persistent_context(browser_tmpdir, headless=False, humanize=True)
page = context.pages[0] if context.pages else context.new_page()
# signup → verify → extract key all within one context
# ...
context.close()
```

**Pattern B — Persistent profile (Proton Mail at ~/proton_profile):**
```python
from cloakbrowser import launch_persistent_context

context = launch_persistent_context(
    PROTON_PROFILE,
    headless=False,
)
page = context.pages[0] if context.pages else context.new_page()
# Already logged in from prior run
# ...
context.close()
```

**Pattern C — Proxy with geoip:**
```python
context = launch_persistent_context(
    browser_tmpdir,
    headless=False,
    humanize=True,
    proxy="socks5://user:pass@proxy:1080",
    geoip=True,   # timezone/locale auto-matched to proxy exit IP
)
```

**Pattern D — Subprocess (Proton fetch in openrouter_signup.py):**

When launching a separate Python process that also needs CloakBrowser, the
subprocess must `from cloakbrowser import launch_persistent_context` independently
— it cannot share the parent's browser context across processes. The subprocess
script is embedded as a string and passed to `sys.executable -c`.

```python
PROTON_FETCH_SCRIPT = r'''
from cloakbrowser import launch_persistent_context
# ... subprocess logic using launch_persistent_context(PROFILE_DIR, headless=False) ...
'''
# Run in subprocess
subprocess.run([sys.executable, "-c", PROTON_FETCH_SCRIPT, ...])
```

**Pattern E — Bash+Python helpers (email.sh / firecrawl_signup.sh style):**

For complex signup flows, write standalone `.py` files to `~/` dir and call
from bash. This is the **user's preferred pattern** for multi-step automation.

**⚠️ CRITICAL: Do NOT use nested heredocs inside command substitution like
`$(python3 << 'EOF')` — bash breaks with quote escaping.** Instead, generate
the `.py` files once at the top of the bash script, then call them with
`python3 ~/helper.py "$ARG"`:

```bash
# In bash: generate .py helpers, then call them
cat > ~/fc_signup.py << 'PYEOF'
from cloakbrowser import launch_persistent_context
import sys, tempfile, atexit, shutil
email, password = sys.argv[1], sys.argv[2]
td = tempfile.mkdtemp()
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))
ctx = launch_persistent_context(td, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto("https://example.com/sign-up", timeout=60000)
# ... fill form, submit ...
ctx.close()
PYEOF

# Call from bash
python3 ~/fc_signup.py "$EMAIL" "$PASSWORD"
```

Advantages: clean separation, no nested heredoc escaping, easy to debug
individual steps.

**DISPLAY env**: If subprocess Python fails with "Missing X server or $DISPLAY",
add `export DISPLAY=:1` (or the correct display for this system) at the top
of the bash script — subprocesses don't always inherit the parent's env.

## User preferences

- **Automation/replacement scripts: bash, minimal lines** — user explicitly said "just give me bash, minimum lines". Prefer `sed`/`awk` one-liners over Python scripts. Single-line bash commands over multi-file solutions.
- **No xvfb-run** — display server is running. `headless=False` works directly.
- **Bash+Python pattern (email.sh style)** — for complex browser automation, write standalone `.py` helper files to `~/` directory (e.g. `~/duckmail.py`, `~/fc_signup.py`), then call them from a bash script with `python3 ~/helper.py "$ARG1" "$ARG2"`. No nested heredocs — they break with quote escaping.
- **Always headless=False** with CloakBrowser on this system.
- **DISPLAY export** — if subprocess Python scripts fail with "Missing X server or $DISPLAY", add `export DISPLAY=:1` (or whatever display the user specifies) at the top of the bash script.

## Form handling: Clerk.js (OpenRouter, Firecrawl, etc.)

Clerk.js intercepts form submissions and reads its own internal React state — **not the DOM**. Standard Playwright `.fill()` hits the DOM but Clerk never sees the change. The Continue button appears enabled but Clerk silently blocks the POST.

**Checkbox fix** — `.check()` and `.click()` on `#legalAccepted-field` don't update Clerk's React state:
```python
# BROKEN: Clerk doesn't see this
page.locator("#legalAccepted-field").check()

# WORKS: dispatches React-compatible events
page.evaluate("""() => {
    const cb = document.querySelector('#legalAccepted-field');
    cb.checked = true;
    cb.dispatchEvent(new Event('change', { bubbles: true }));
    cb.dispatchEvent(new Event('input', { bubbles: true }));
}""")
```

**Alternative**: `page.locator('#legalAccepted-field').check(force=True)` also works
because it bypasses Playwright's actionability checks and fires the native click event.

**Text input**: `.fill()` usually works for Clerk email/password fields. If the form
doesn't submit after fill + checkbox + Continue, try `.type(text, delay=80)` instead
to simulate real keystroke events that Clerk's React listeners catch.

**Detecting the silent block**: If clicking Continue produces zero Clerk POST requests
but the page just resets to the empty form, Clerk is silently rejecting. Check with
network listener: `page.on('request', lambda r: print(r.method, r.url) if 'clerk' in r.url else None)`.

## Headless mode

**Always use `headless=False`** — the user has a running display server and
`headless=True` crashes CloakBrowser v146 (free tier) on this system with
`TargetClosedError: Target page, context or browser has been closed`.

No `xvfb-run` needed — the display server is live. Run scripts directly:
```bash
python3 scripts/openrouter_signup.py
```

If running on a headless machine without a display, wrap with `xvfb-run`
(available at `/nix/store/*/bin/xvfb-run`):
```bash
xvfb-run python3 scripts/your_script.py
```

## Cloudflare handling

CloakBrowser **auto-solves Cloudflare Turnstile** (both non-interactive and
managed challenges) in most cases. No manual CF-click logic is needed.

**Important exception — Clerk-managed Turnstile (OpenRouter, Firecrawl):**
Clerk renders Turnstile in invisible/managed mode AFTER form validation passes.
The challenge iframe doesn't appear until Clerk's React state is properly synced
(see Form handling section above). If you see `POST /sign-up` with empty body `[]`
and zero Clerk POSTs, Clerk isn't submitting because it doesn't see the field values.
Fix the form state first (dispatchEvent), then Turnstile will render and auto-solve.

**Turnstile detection pitfall — inline vs iframe:**
Some sites (OpenRouter) embed Turnstile **inline on the main page** (`.cf-turnstile` div or `#challenge-stage`), NOT inside a detectable iframe with `challenges.cloudflare.com` in the URL. The old pattern of only checking `frame.url` for cloudflare misses these entirely.

```python
# WRONG: only checks iframes — misses inline Turnstile
for frame in p.frames:
    if "challenges.cloudflare.com" in frame.url:
        # ... click checkbox

# CORRECT: check main page first, then frames
# 1. Inline Turnstile on main page
try:
    turnstile = p.locator(".cf-turnstile, iframe[src*='challenges.cloudflare.com'], #challenge-stage")
    if turnstile.first.is_visible(timeout=500):
        cb = turnstile.first.locator("input[type='checkbox'], .ctp-checkbox, body").first
        if cb.is_visible(timeout=300):
            cb.click()
except: pass
# 2. Frame-based Turnstile (traditional)
for frame in p.frames:
    if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
        try:
            cb = frame.locator("input[type='checkbox'], .ctp-checkbox, #challenge-stage, body")
            if cb.first.is_visible(timeout=500):
                cb.first.click()
        except: pass
# 3. Success check — run EVERY iteration regardless of turnstile detection
if "confirm-email" in p.url or "verification" in p.inner_text("body")[:300].lower():
    break
```

**Key insight**: The success-condition check (`confirm-email` in URL/body) must run on **every** loop iteration, not be gated behind `if not turnstile`. Otherwise the script loops 30× waiting for a turnstile that already passed.

**Manual fallback (rare):** If CloakBrowser auto-solve fails on a non-Clerk site,
use the `FakeShadowRoot` method documented in the Cloudflare handling section above
(`--enable-blink-features=FakeShadowRoot` launch arg + JS shadow-DOM walker).

```python
# Launch with FakeShadowRoot enabled (CloakBrowser-specific Blink feature)
context = launch_persistent_context(
    tmpdir,
    headless=False,
    humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"],
)

# JS: walk open + closed shadow roots to find the Turnstile checkbox
_FIND_CHECKBOX_JS = """() => {
  function find(root){
    if(!root) return null;
    const direct = root.querySelector && root.querySelector('input[type=checkbox]');
    if(direct) return direct;
    for(const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])){
      const sr = el.fakeShadowRoot || el.shadowRoot;
      if(sr){ const r = find(sr); if(r) return r; }
    }
    return null;
  }
  const cb = find(document);
  if(!cb) return {found:false};
  const r = cb.getBoundingClientRect();
  return {found:true, checked:cb.checked, x:r.x+r.width/2, y:r.y+r.height/2, w:r.width};
}"""

def handle_cf_turnstile(page):
    """Fallback: click Turnstile checkbox via FakeShadowRoot (CloakBrowser only)."""
    for frame in page.frames:
        if "challenges.cloudflare" in (frame.url or ""):
            try:
                info = frame.evaluate(_FIND_CHECKBOX_JS)
                if not info.get("found") or info.get("checked"):
                    return False
                frame_el = frame.frame_element()
                box = frame_el.bounding_box()
                if not box:
                    return False
                # checkbox coords are iframe-relative; offset by iframe's page position
                page.mouse.click(box["x"] + info["x"], box["y"] + info["y"])
                page.wait_for_timeout(3000)
                return True
            except:
                pass
    return False
```

**Why this works:** Cloudflare Turnstile renders its checkbox inside a **closed**
shadow root. Standard Playwright frame locators can't penetrate it. CloakBrowser's
`--enable-blink-features=FakeShadowRoot` flag exposes `el.fakeShadowRoot` natively,
so the JS walker can find and click the checkbox without any external patches.

## Conversion pitfalls (Playwright → CloakBrowser)

1. **No `sync_playwright()` context manager** — CloakBrowser's `launch()` /
   `launch_persistent_context()` are top-level functions. Remove the
   `with sync_playwright() as p:` wrapper entirely. Just call `launch()` or
   `launch_persistent_context()` directly.
2. **`humanize=True` replaces manual helpers** — no need for custom
   `human_type()` / `human_click()` functions with random delays. CloakBrowser
   patches all Playwright interactions at the CDP level.
3. **`geoip=True` replaces manual locale/timezone** — set it when using a
   proxy and timezone/locale should match the exit IP.
4. **`proxy` is a string`, not `{"server": "..."}` dict** — CloakBrowser accepts
   `"socks5://user:pass@host:port"` or `"http://user:pass@host:port"` directly.
5. **No `executable_path` needed** — CloakBrowser bundles its own stealth
   Chromium binary (auto-downloaded on first use via `python -m cloakbrowser install`).
6. **`context.close()` is still required** — CloakBrowser returns real Playwright
   objects; early `return` without closing leaks the browser process. Use
   `try/finally` to ensure cleanup.
7. **Free tier = v146** (previous Chromium), **Pro = v148+** (latest patches).
   Free tier goes stale within weeks. Set `license_key` param or
   `CLOAKBROWSER_LICENSE_KEY` env var for Pro.
8. **Font warning on Linux** — `No Windows fonts found` message is cosmetic.
   Suppress with `CLOAKBROWSER_SUPPRESS_FONT_WARNING=1`.
9. **Subprocess scripts must import CloakBrowser independently** — embedded
   script strings passed to `sys.executable -c` need their own
   `from cloakbrowser import ...` import.
10. **`shutil.rmtree` uses `ignore_errors=True`**, NOT `ignore=True`** — common typo
    when porting Python cleanup code. `ignore` is not a valid keyword argument.
11. **Sed one-liner for bulk playwright→cloakbrowser replacement:**
    ```bash
    grep -rl 'sync_playwright' scripts/ | xargs sed -i 's/from playwright.sync_api import sync_playwright/from cloakbrowser import launch, launch_persistent_context/g; s/p\.chromium\.launch_persistent_context/launch_persistent_context/g; /^with sync_playwright() as p:$/d; /executable_path=/d; s/headless=False,/headless=False, humanize=True,/g'
    ```
    Note: after running sed, you must manually **un-indent** the body that was
    inside the `with` block, and remove `p.stop()`.

## Diagnostic checklist (when browser scripts break)

1. **Syntax check**: `bash -n script.sh` / `python3 -m py_compile script.py`
2. **CloakBrowser installed**: `python3 -c "from cloakbrowser import launch; print('OK')"`
3. **Binary downloaded**: `python3 -m cloakbrowser info`
4. **Test minimal context**: `launch_persistent_context(tmpdir, headless=False) → new_page → goto example.com`
5. **Proxy dead?**: Test connectivity before launching browser
6. **Cloudflare issue?**: CloakBrowser should auto-solve; if not, check for CF iframe fallback
7. **Script hanging?**: Check if `context.close()` is called on all exit paths (including error/early return)
8. **License issues?**: Free tier v146 may be stale; check `python3 -m cloakbrowser update`
9. **`headless=True` CRASHES with CloakBrowser v146** — `TargetClosedError`. Always use `headless=False`. If no display server, wrap with `xvfb-run`.
10. **Clerk.js form fields need `dispatchEvent`** — `.fill()` and `.check()` do NOT trigger Clerk's internal React state. The button appears enabled but Clerk never POSTs to its API. Fix: use JS `dispatchEvent` after setting values, or `check(force=True)` for checkboxes.
14. **Turnstile inline vs iframe** — OpenRouter embeds Turnstile inline on the main page (`.cf-turnstile`), not in a detectable iframe. Check main page first, then frames. See Cloudflare handling section for the correct detection pattern.
15. **Success check gated behind turnstile detection** — If your `confirm-email` URL check is inside `if not turnstile:`, it never runs after Turnstile passes. Always check success condition on every loop iteration.
16. **`pipefail` + `grep` kills script** — With `set -eo pipefail`, `grep` with no matches causes silent script death. Use `tail -1` not `head -1`, `sed` not `cut` for URLs, and `if` not `&&` for the empty check.
17. **Python stdout not flushed before `ctx.close()` + `sys.exit(0)`** — Pipe capture gets empty string. Always `flush=True` and `sys.stdout.flush()` before closing. Break out of nested loops and print after, not inside.
18. **Common profile across signup+verify steps** — When a signup flow has multiple browser steps (signup → verify → extract), use the **same persistent profile** for all steps, not separate tmpdirs. Cloudflare challenge state and session cookies earned during signup must carry over to verify. Proton Mail gets its own separate profile. Example: `~/or_profile` shared between `or_signup.py` and `or_verify.py`.
19. **`CloakBypasser` (CloudflareBypassForScraping) for CF-heavy flows** — When CloakBrowser's auto-solve isn't enough, use the `CloakBypasser` class from `cf_bypasser`. It's async, uses `get_or_generate_html()` to solve challenges, and you bridge to a persistent context by restoring cookies. Install: `pip install git+https://github.com/sarperavci/CloudflareBypassForScraping.git -i https://pypi.org/simple/`. See `references/openrouter-signup-flow.md` for the full two-phase pattern.

## Cloudflare bypass flow (from sarperavci/CloudflareBypassForScraping)

The reference implementation at
[`sarperavci/CloudflareBypassForScraping`](https://github.com/sarperavci/CloudflareBypassForScraping)
uses this flow (adapted for CloakBrowser's sync API):

```python
import asyncio
from cloakbrowser import launch_persistent_context

# 1. Launch with FakeShadowRoot enabled
context = launch_persistent_context(
    tmpdir,
    headless=False,
    humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"],
    proxy="socks5://user:pass@proxy:1080",  # optional
    geoip=True,  # auto timezone/locale from proxy IP
)
page = context.pages[0] if context.pages else context.new_page()

# 2. Navigate and let challenge scripts load
page.goto(url, timeout=60000)
page.wait_for_timeout(5000)  # CHALLENGE_SETTLE_SECONDS

# 3. Check if already bypassed
async def is_bypassed(page):
    title = page.title()
    if "just a moment" in title.lower():
        return False
    html = page.content()
    if "please complete the captcha" in html.lower():
        return False
    if any(m in html.lower() for m in ("you have been blocked", "error 1020", "access denied")):
        return False
    return True

# 4. If CF detected, try auto-solve then manual click
if not is_bypassed(page):
    # Wait for auto-solve (non-interactive challenges resolve on their own)
    for _ in range(10):
        page.wait_for_timeout(2000)
        if is_bypassed(page):
            break
    # If still blocked, try the FakeShadowRoot click
    if not is_bypassed(page):
        handle_cf_turnstile(page)  # uses the fallback from Cloudflare handling section

# 5. Extract cookies for your own HTTP client
cookies = context.cookies()  # list of {name, value, domain, ...}
user_agent = page.evaluate("navigator.userAgent")
```

**Key differences from vanilla Playwright:**
- `args=["--enable-blink-features=FakeShadowRoot"]` — CloakBrowser-specific Blink flag
- `el.fakeShadowRoot` in JS — natively accesses closed shadow roots
- `geoip=True` — auto-derives timezone/locale from proxy exit IP
- Cookie + user-agent pair must be sent together or Cloudflare rejects the cookie

**Alternative: FastAPI server** — For a managed bypass proxy with cookie caching and request mirroring, use the [CloudflareBypassForScraping](https://github.com/sarperavci/CloudflareBypassForScraping) server (`pip install -e . && python server.py`). See `references/cloudflare-bypass.md` for full setup.

## Support files

- `references/camoufox-playwright-cdp-compat.md` — historical Camoufox notes, `isMobile` CDP patch (no longer needed with CloakBrowser)
- `references/clerkjs-form-debugging.md` — Clerk.js form state issues, dispatchEvent workaround, network-level debugging recipe, Turnstile auto-solve flow
- `references/firecrawl-cli.md` — Firecrawl CLI install, auth, and usage reference
- `references/cloakbrowser-bash-pattern.md` — bash+python helper pattern, nested heredoc pitfall, DISPLAY env, sed migration one-liner, pipefail+grep pitfall, stdout flush before exit
- `references/proton-mail-automation.md` — Proton Mail inbox automation: persistent profile, search, extract verification links, bash integration
- `references/cloudflare-bypass.md` — Full CloudflareBypassForScraping integration: server setup (FastAPI/Docker), API endpoints, request mirroring, FakeShadowRoot, solve flow, cookie extraction
- `references/openrouter-signup-flow.md` — OpenRouter signup: Clerk.js form, inline Turnstile, Proton verification, API key extraction
- `scripts/cloak_replace.sh` — One-liner bulk sed script to migrate playwright→cloakbrowser in all workspace scripts
