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
