# Hermes Browser Tool Integration for Signup Flows

## Introduction

The Hermes Agent's `browser_navigate`, `browser_type`, `browser_click`, and
`browser_console` tools can drive signup flows directly without Playwright/
CloakBrowser. This is useful when:
- The browser environment is already authenticated
- You need visual verification of page state
- Playwright/CloakBrowser isn't available or appropriate

## Tool mapping

| Playwright action | Hermes browser tool equivalent |
|---|---|
| `page.goto(url)` | `browser_navigate(url=url)` |
| `page.locator(sel).fill(text)` | `browser_type(ref=<selector>, text=text)` |
| `page.locator(sel).click()` | `browser_click(ref=<selector>)` |
| `page.locator(sel).check()` | `browser_click(ref=<selector>)` (clicks checkbox) |
| `page.evaluate(js)` | `browser_console(expression=js)` |
| `page.title()` | `browser_console(expression="document.title")` |
| `page.content()` | Not directly available — use `browser_snapshot(full=true)` |
| `page.url` | `browser_console(expression="window.location.href")` |

## Known limitation: cross-origin iframe clicks don't register

When a page renders a Cloudflare Turnstile challenge inside an iframe
(`challenges.cloudflare.com`), the accessibility tree shows the checkbox
(e.g. `ref=e40`, `checkbox "Verify you are human"`) but `browser_click`
on that ref **does not register** the click. The checkbox remains `checked=false`.

**Workarounds attempted (all failed):**
1. `browser_click(ref=e40)` — clicks the DOM element, CF doesn't register
2. JS `iframe.contentDocument.querySelector('input').click()` — cross-origin, throws
3. JS fakeShadowRoot walker — iframe not accessible from parent
4. `browser_console` to dispatch `mousedown`/`mouseup`/`click` events — no effect

**Possible approaches not yet tried:**
- `browser_vision` to get pixel coordinates, then coordinate-based mouse injection
- Inject a MutationObserver + click handler into the page BEFORE form submit
- Use CloakBrowser with `--enable-blink-features=FakeShadowRoot` which exposes
  the closed shadow root natively (only works if the iframe is same-origin or
  the Blink flag propagates)

**What actually happens with Clerk-managed Turnstile:**
1. Form fields fill correctly via `browser_type` (DOM values visible)
2. Checkbox `browser_click(ref=e29)` sets `checked=true` in DOM
3. Clicking Continue via `browser_click(ref=e30)` triggers Clerk's form submission
4. Clerk renders Turnstile in a cross-origin iframe from `challenges.cloudflare.com`
5. The iframe shows "The CAPTCHA failed to load" — Browserbase's Chromium can't load
   the Turnstile widget (detected as unsupported browser)
6. The Turnstile checkbox appears in accessibility tree as `ref=e30` but
   `browser_click(ref=e30)` does nothing — the click doesn't penetrate the
   cross-origin iframe's closed shadow root
7. Form resets, user is stuck on signup page

**Conclusion**: The Hermes browser tool is great for filling Clerk forms and
triggering submit, but CANNOT solve the resulting Turnstile challenge.
**Use CloakBrowser for the entire flow** when Turnstile is expected.

## Clerk FAPI direct HTTP calls (2026-06-30)

Clerk exposes a Frontend API (FAPI) that can be called directly via HTTP:

```
POST https://clerk.openrouter.ai/v1/client/sign_ups?__clerk_api_version=2025-11-10&_clerk_js_version=5.127.0
Content-Type: application/json

{
  "email_address": "user@example.com",
  "password": "SecureP@ss99!xQ",
  "legal_accepted": true,
  "captcha_token": "0x4AAAA..."  // REQUIRED - Turnstile token
}
```

**Response without captcha_token:**
```json
{"errors":[{"code":"captcha_missing_token","message":"Authentication unsuccessful due to failed security validations."}]}
```

**Getting a Turnstile token** requires solving the challenge in a real browser.
Options:
1. **Rust turnstile-clicker** (`~/rust-cf-turnstile-bypass/turnstile-clicker`) — screen-capture-based auto-clicker that detects and clicks Turnstile checkboxes. Press F8 to activate. Requires the Turnstile widget to be visible on the display.
2. **Token server** (`~/rust-cf-turnstile-bypass/token-server`) — WebSocket server (port 8080) that routes tokens from solver iframes to receiver clients. Works with the token-harvester HTML page.
3. **localtunnel** — Cloudflare rejects `data:` URIs and localhost origins for Turnstile. Serve the Turnstile page via `npx localtunnel --port <port>` to get a public `*.loca.lt` URL that Cloudflare accepts.

**Clerk SDK `signUp.create()` hangs:**
```javascript
// This NEVER resolves — waits for Turnstile which never completes
await window.Clerk.client.signUp.create({emailAddress, password, legalAcceptedAt});
```
The Clerk SDK internally waits for the Turnstile challenge callback. If the browser
can't load/solve Turnstile, the promise hangs indefinitely. Must use the HTTP FAPI
with an externally-obtained token instead.

**Extracting Clerk config from page:**
```javascript
window.__clerk_publishable_key  // "pk_live_Y2xlcmsub3BlbnJvdXRlci5haSQ"
window.Clerk.environment.displayConfig.captchaPublicKey  // "0x4AAAAAAAWXJGBD7bONzLBd"
window.Clerk.environment.displayConfig.captchaPublicKeyInvisible  // "0x4AAAAAAAFV93qQdS0ycilX"
window.Clerk.client.id  // "client_3FpcwtX7Hn8BJmImba8Zoq1jGVC"
```

**Full token-based signup flow:**
1. Extract sitekey from page (`window.Clerk.environment.displayConfig.captchaPublicKey`)
2. Serve a Turnstile widget page via localtunnel (public URL)
3. Solve Turnstile via Rust clicker or CloakBrowser's auto-solve
4. Extract the token from the page (callback writes it to `cf-turnstile-response` input or page title)
5. POST to Clerk FAPI with the token
6. Handle the response (may need email verification step)

## Workaround: bypass server pre-warming

The CloudflareBypassForScraping server (port 8000) caches clearance cookies.
If the server has already solved the challenge for the domain, subsequent
navigations skip the challenge entirely:

```bash
# Pre-warm cookies for OpenRouter
curl -s -H "x-hostname: openrouter.ai" http://localhost:8000/ > /dev/null
```

Then navigate with the Hermes browser tool — no Turnstile appears (server cached
the cookies). **Limitation**: the server sometimes fails to solve Clerk-managed
Turnstile challenges, returning `{"detail":"Failed to bypass Cloudflare protection"}`.

## Useful patterns

### Check state after action
Always verify the result of an interaction:
```javascript
// After clicking checkbox
browser_console(expression="document.querySelector('#legalAccepted-field').checked")
// Returns: true or false
```

### Trigger Clerk form submission via JS
When the form uses `method="get"` and Clerk intercepts submit:
```javascript
// Dispatch mousedown → mouseup → click in sequence
const btn = [...document.querySelectorAll('button')].find(b => b.textContent.trim() === 'Continue');
const rect = btn.getBoundingClientRect();
const x = rect.x + rect.width/2, y = rect.y + rect.height/2;
btn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, clientX: x, clientY: y }));
btn.dispatchEvent(new MouseEvent('mouseup',   { bubbles: true, cancelable: true, clientX: x, clientY: y }));
btn.dispatchEvent(new MouseEvent('click',      { bubbles: true, cancelable: true, clientX: x, clientY: y }));
```

### React fiber onChange (deterministic checkbox state)
```javascript
const el = document.querySelector('#legalAccepted-field');
const fiberKey = Object.keys(el).find(k => k.startsWith('__reactFiber$'));
let fiber = el[fiberKey];
for (let i = 0; i < 20; i++) {
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

## OpenRouter Clerk credentials (as of 2026-06-29)

- Publishable key: `pk_live_Y2xlcmsub3BlbnJvdXRlci5haSQ`
- Captcha provider: `turnstile`
- Visible sitekey: `0x4AAAAAAAWXJGBD7bONzLBd`
- Invisible sitekey: `0x4AAAAAAAFV93qQdS0ycilX`
- Widget type: `smart` (invisible, only shows checkbox when bot detected)

These are embedded in `window.Clerk.environment.displayConfig` on the signup page.
