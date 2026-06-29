# Clerk.js Form Debugging (OpenRouter Signup)

## Session: 2026-07-01

## Problem

OpenRouter signup at `/sign-up` uses Clerk.js for auth. After filling
email, password, and checking the "I agree" checkbox, clicking
"Continue" does nothing — no Clerk API POST, no navigation, just a
silent form reset.

## Root cause

Clerk.js maintains its own internal React component state. It reads
form values from React state (not the DOM). Standard Playwright
`.fill()` and `.check()` update the DOM but NOT Clerk's React state,
so Clerk never sees the values and silently blocks submission.

## Evidence

### Network requests after clicking Continue
- ZERO POST requests to `clerk.openrouter.ai`
- Only analytics/analytics POSTs (Google Analytics, PostHog)
- No Turnstile iframe rendered (Clerk never got far enough to trigger it)

### Request log (from `logs/requests.json`)
- 167 total requests, 15 POST requests
- ALL POSTs were analytics (GA, PostHog, Cloudflare RUM)
- Clerk only made GET requests (JS bundles, environment, client)

### Form state
- `.fill()` on email/password: DOM values updated, Clerk doesn't see them
- `.check()` on legalAccepted: DOM checkbox stays unchecked, Clerk doesn't see it
- `.check(force=True)`: DOM checkbox becomes checked, but Clerk still doesn't react
- JS `dispatchEvent`: Both DOM + Clerk state update, Continue button becomes enabled

### CloakBrowser + headless
- `headless=True`: CloakBrowser v146 immediately closes with `TargetClosedError`
- `headless=False` under `xvfb-run`: Works correctly
- `headless=False` without xvfb-run: Hangs (no display server)

## Working approach

```python
from cloakbrowser import launch_persistent_context
import tempfile, shutil, atexit

td = tempfile.mkdtemp(prefix="browser-profile-")
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))

context = launch_persistent_context(td, headless=False, humanize=True)
page = context.pages[0] if context.pages else context.new_page()
page.goto("https://openrouter.ai/sign-up", timeout=60000)
page.wait_for_timeout(3000)

# Fill text fields (fill works for email/password)
page.locator("#emailAddress-field").fill(email)
page.locator("#password-field").fill(password)

# Checkbox — MUST use dispatchEvent or check(force=True)
page.evaluate("""() => {
    const cb = document.querySelector('#legalAccepted-field');
    cb.checked = true;
    cb.dispatchEvent(new Event('change', { bubbles: true }));
    cb.dispatchEvent(new Event('input', { bubbles: true }));
}""")

page.wait_for_timeout(500)
page.get_by_role("button", name="Continue").click()
# Now Clerk should POST to /v1/client/sign_ups
```

## Diagnostic commands

```bash
# Run with xvfb-run on Replit/NixOS
xvfb-run python3 scripts/openrouter_signup.py

# Check CloakBrowser install
python3 -m cloakbrowser info

# Test minimal context
python3 -c "from cloakbrowser import launch_persistent_context; \
  ctx=launch_persistent_context('/tmp/test-cb',headless=False); \
  p=ctx.pages[0] if ctx.pages else ctx.new_page(); \
  p.goto('https://example.com'); print('OK'); ctx.close()"
```

## Network-level debugging recipe

When a Clerk form appears to submit but nothing happens:

1. **Log all network requests**:
```python
page.on("request", lambda r: print(f'{r.method} {r.url[:150]}')
         if 'clerk' in r.url else None)
```

2. **Check for the empty-body POST**: If you see `POST /sign-up` with body `[]`,
   that's the native form element submitting without Clerk intercepting it.
   Clerk never fired its own `POST /v1/client/sign_ups` because it didn't
   recognize the field values in its React state.

3. **Check Turnstile token**:
```python
page.evaluate("document.querySelector('[name=cf-turnstile-response]')?.value || 'none'")
```
If `none`, Clerk never triggered Turnstile rendering, confirming form state is broken.

4. **Check Clerk globals**:
```python
page.evaluate("() => Object.keys(window).filter(k => k.toLowerCase().includes('clerk'))")
# Should return: ['Clerk', '__clerk_publishable_key', ...]
```

5. **Full request logging to file** (for offline analysis):
```python
import json
all_requests = []
def on_req(r):
    entry = {"method": r.method, "url": r.url[:300]}
    if r.method == "POST":
        try: entry["post_data"] = (r.post_data or "")[:300]
        except: pass
    all_requests.append(entry)
page.on("request", on_req)
# ... after interaction ...
with open("logs/requests.json", "w") as f:
    json.dump(all_requests, f, indent=2)
```

## OpenRouter-specific notes

- Clerk publishable key: `pk_live_Y2xlcmsub3BlbnJvdXRlci5haSQ`
- Turnstile is rendered by Clerk AFTER form validation passes (managed/invisible mode)
- No `data-sitekey` attribute visible — Clerk manages Turnstile internally
- Clerk JS version: 5.127.0 (as of 2026-07-01)
- `POST openrouter.ai/sign-up body=[]` is a **red herring** — it's the native form
  element submitting with no data. The real submission goes through Clerk's JS API.

## Turnstile auto-solve behavior with CloakBrowser

CloakBrowser auto-solves Turnstile on *most* sites. For Clerk-managed Turnstile
(OpenRouter, Firecrawl), the flow is:

1. Clerk validates form state in React
2. If valid → Clerk renders invisible/managed Turnstile iframe
3. CloakBrowser auto-solves the challenge
4. Clerk submits with the token

If step 1 fails (Clerk doesn't see form values), Turnstile never renders.
**Fix the form state first** (dispatchEvent), then Turnstile will auto-solve.
