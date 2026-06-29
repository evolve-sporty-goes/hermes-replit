# Clerk.js Form Debugging (OpenRouter, Firecrawl Signup)

## Problem

Sites using Clerk.js for auth (OpenRouter `/sign-up`, Firecrawl `/signin`)
have forms where clicking "Continue" after filling fields does nothing —
no Clerk API POST, no navigation, just a silent form reset.

## Root cause

Clerk.js maintains its own internal React component state. It reads
form values from React state (not the DOM). Standard Playwright
`.fill()` and `.check()` update the DOM but NOT Clerk's React state,
so Clerk never sees the values and silently blocks submission.

## Evidence

### Network requests after clicking Continue
- ZERO POST requests to `clerk.openrouter.ai`
- Only analytics POSTs (Google Analytics, PostHog)
- No Turnstile iframe rendered (Clerk never got far enough to trigger it)

### Request log (from `logs/requests.json`)
- 167 total requests, 15 POST requests
- ALL POSTs were analytics (GA, PostHog, Cloudflare RUM)
- Clerk only made GET requests (JS bundles, environment, client)

### Form state
- `.fill()` on email/password: DOM values updated, Clerk doesn't see them
- `.check()` on legalAccepted: DOM checkbox stays unchecked, Clerk doesn't see it
- `.check(force=True)`: DOM checkbox becomes checked, but Clerk still doesn't react
- `.click(force=True)`: DOM checkbox becomes checked, `is_checked()` returns True
- JS `dispatchEvent`: Both DOM + Clerk state update, Continue button becomes enabled

## Working approaches

### Approach 1: dispatchEvent (most reliable)
```python
page.locator("#emailAddress-field").fill(email)
page.locator("#password-field").fill(password)

page.evaluate("""() => {
    const cb = document.querySelector('#legalAccepted-field');
    cb.checked = true;
    cb.dispatchEvent(new Event('change', { bubbles: true }));
    cb.dispatchEvent(new Event('input', { bubbles: true }));
}""")

page.wait_for_timeout(500)
page.get_by_role("button", name="Continue").click()
```

### Approach 2: check(force=True) (simpler, works for checkbox)
```python
page.locator("#legalAccepted-field").check(force=True)
```

### Approach 3: type() with delay (for text fields that .fill() doesn't trigger)
```python
page.locator("#emailAddress-field").type(email, delay=80)
```

## Detecting the silent block

If clicking Continue produces zero Clerk POST requests but the page
just resets to the empty form, Clerk is silently rejecting.

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

4. **Full request logging to file** (for offline analysis):
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
