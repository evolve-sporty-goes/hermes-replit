# OpenRouter Signup Debugging Session (2026-06-29)

## Context
Attempted to sign up for OpenRouter via the web UI using browser automation.
Email generated via `email.sh`: `ongoing-aliens-tug@duck.com`

## Architecture
OpenRouter uses Clerk.js for auth. The signup flow:
1. Fill email + password on `https://openrouter.ai/sign-up`
2. Check `#legalAccepted-field` checkbox
3. Click Continue
4. Clerk renders Turnstile challenge (managed/invisible mode)
5. Solve Turnstile → Clerk submits → redirect to confirm-email page
6. Check Proton Mail for verification link
7. Click link → extract API key

## What Failed

### Attempt 1: Hermes browser tool
- Filled fields via `browser_type` — worked
- Checked checkbox via `browser_click(ref=e29)` — showed checked in snapshot
- Clicked Continue → Turnstile iframe appeared but showed "CAPTCHA failed to load"
- `browser_click` on Turnstile checkbox (ref=e30) — no effect
- **Root cause**: Cross-origin iframe, browser tool cannot penetrate

### Attempt 2: CloakBrowser with DISPLAY=:1
- Filled fields via `.fill()` — values confirmed in DOM
- Checked checkbox via `.check(force=True)` — `is_checked()` returned True
- Clicked Continue → stayed on signup page, no navigation, no Turnstile
- **Root cause**: Clerk's React state not synced despite DOM being correct

### Attempt 3: React fiber manipulation
- Walked `__reactFiber$` tree to find `memoizedProps.onChange`
- Called with synthetic event object — didn't help
- Clerk's internal `signUp.emailAddress` remained `null`

### Attempt 4: Hidden submit button
- Found `button[type="submit"]` inside Clerk form (hidden via CSS)
- Clicked via JS → Turnstile appeared (progress!) but same failure as Attempt 1

### Attempt 5: Keyboard simulation
- Tabbed to checkbox, pressed Space → checkbox showed checked
- Pressed Enter → no navigation

## Key Findings

1. **Clerk form with CloakBrowser**: Even when DOM shows correct state, Clerk's internal
   React state may not be synced. The Continue button click does nothing.

2. **Hidden submit button**: Clicking `form button[type="submit"]` via JS triggers the
   same flow as the visible Continue button. Useful when the visible button is
   intercepted by React event handlers that don't fire from `.click()`.

3. **Turnstile inline detection**: OpenRouter embeds Turnstile inline (`.cf-turnstile`
   div or `#challenge-stage`), NOT in a detectable iframe with `challenges.cloudflare.com`
   in the URL. The old pattern of only checking `frame.url` for cloudflare misses these.

4. **Success condition**: After signup, URL changes to contain `confirm-email` or body
   contains "check your" / "verification". This check must run on EVERY loop iteration,
   not be gated behind turnstile detection.

## The Unsolved Problem (as of 2026-06-29)
We could not get CloakBrowser to submit the Clerk signup form despite having all
fields correctly filled. The issue is likely that Clerk's React internal state
requires a specific event sequence that we haven't reproduced.

## RESOLVED (2026-07-01)
The working pattern that successfully triggers Clerk Turnstile:
1. `page.locator("#emailAddress-field").type(email, delay=50)` — NOT `.fill()`
2. `page.locator("#password-field").type(password, delay=50)` — NOT `.fill()`
3. Checkbox via React fiber `onChange` (deterministic, doesn't toggle):
   ```javascript
   const el = document.querySelector('#legalAccepted-field');
   const fk = Object.keys(el).find(k => k.startsWith('__reactFiber$'));
   let fiber = el[fk];
   for (let i = 0; i < 30; i++) {
       if (fiber?.memoizedProps?.onChange) {
           fiber.memoizedProps.onChange({
               target: { checked: true, type: 'checkbox' },
               currentTarget: { checked: true },
               nativeEvent: new Event('change', { bubbles: true }),
               type: 'change', preventDefault(){}, stopPropagation(){}, persist(){}
           });
           break;
       }
       fiber = fiber.return;
   }
   ```
4. `page.get_by_role("button", name="Continue").click()` with `humanize=True`
5. After ~8s, `document.querySelector('[name="cf-turnstile-response"])` EXISTS
   (Turnstile rendered — Clerk saw the form values!)
6. CloakBrowser auto-solves OR user clicks manually on display 1

**Key insight**: `.fill()` doesn't trigger Clerk's React input handlers. `.type()`
with delay simulates real keystrokes that Clerk's listeners catch. Combined with
the deterministic React fiber checkbox approach, Clerk finally validates the form
and renders Turnstile.

**Turnstile solver (icemellow-me) does NOT work** for this sitekey — returns
`ERROR_CAPTCHA_UNSOLVABLE`. Must use CloakBrowser's stealth Chromium.

## Recommendation (updated 2026-07-01)
For Clerk signup flows:
1. Use CloakBrowser with `DISPLAY=:1`, `headless=False`, `humanize=True`
2. Fill fields with `.type(delay=50)`, NOT `.fill()`
3. Checkbox via React fiber `onChange` (deterministic)
4. Click Continue with humanized mouse
5. Wait for Turnstile to render (check `[name="cf-turnstile-response"]` exists)
6. CloakBrowser auto-solves OR leave browser open for manual click on display 1
7. Poll URL for `confirm-email` / `verify` / `check your`

## Credentials Generated During Session
- Email: `ongoing-aliens-tug@duck.com` (Duck Address)
- Password: `xK9mP2nQ7wR4vL8s` (random)
- Proton: `bavmin` / `Satyana@1234` (from config.py)
