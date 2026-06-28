# Cloudflare / Turnstile Challenge Auto-Click Handler

> **Status: VERIFIED** — This auto-click/iframe-iteration approach works reliably in production (confirmed Jun 2026 across TorBox, OpenRouter, Proton Mail, and Firecrawl signup flows). It is the go-to approach for Cloudflare challenges in browser automation.

## When to Use

After clicking a submit/continue button on a site protected by Cloudflare Turnstile or hCaptcha, the challenge may appear as an inline iframe before the next page loads. This happens frequently on signup and login forms. The page appears "stuck" until the challenge is solved.

## Pattern: Iterate `page.frames` and Click

The most reliable approach — works for both `challenges.cloudflare.com` iframes and inline widget frames:

```python
# After clicking the submit button:
page.wait_for_timeout(5000)  # Let the challenge frame render

for frame in page.frames:
    if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
        try:
            frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()
            page.wait_for_timeout(4000)  # Wait for token generation / validation
            print("Cloudflare challenge clicked")
        except Exception:
            pass
        break
```

### Why this works

- Cloudflare challenges render inside an iframe. The main `page.locator()` cannot reach into iframe content — you must use `frame.locator()`.
- The frame URL contains `challenges.cloudflare.com` (Turnstile) or the name contains "cloudflare".
- `#challenge-stage` is the hCaptcha area; `.ctp-checkbox` is the Cloudflare Turnstile checkbox; `body` is a fallback for custom challenge layouts.
- The 4000ms wait after clicking lets Cloudflare's JS validate the challenge and issue the cf_clearance cookie.

## Integration Point in Multi-Step Workflows

Place this handler **immediately after** clicking submit/continue buttons in signup or login flows. Example from OpenRouter signup:

```python
# Click Continue
page.get_by_role("button", name="Continue").click()
page.wait_for_timeout(5000)

# Handle Cloudflare challenge if it appears
for frame in page.frames:
    if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
        try:
            frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()
            page.wait_for_timeout(4000)
        except Exception:
            pass
        break

# Wait for page to settle after Cloudflare
page.wait_for_timeout(8000)
```

## Proton Mail Login: Same Pattern

Cloudflare also appears on the Proton Mail login page. The same handler works there — place it after navigating to `https://account.proton.me/login` and before filling credentials:

```python
page.goto("https://account.proton.me/login", timeout=60000)
page.wait_for_timeout(5000)

# Handle Cloudflare if present
for frame in page.frames:
    if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
        try:
            frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()
            page.wait_for_timeout(4000)
        except Exception:
            pass
        break

# Now safe to fill login form
page.locator("#username").fill(PROTON_USER)
```

## Alternative: `frame_locator` Approach

For the common Turnstile widget (title contains "Cloudflare security challenge"), Playwright's `frame_locator` is an alternative:

```python
try:
    cf_checkbox = page.frame_locator(
        "iframe[title='Widget containing a Cloudflare security challenge']"
    ).locator("input[type='checkbox']")
    if cf_checkbox.is_visible(timeout=5000):
        cf_checkbox.check()
        page.wait_for_timeout(10000)
except Exception:
    pass
```

**Caveat:** The `frame_locator` approach only works for the standard Turnstile widget with that specific title attribute. The `page.frames` iteration is more general — it catches custom Cloudflare challenge pages, hCaptcha via Cloudflare, and non-standard iframe names.

## Pitfalls

1. **Don't skip the post-click wait** — Cloudflare validation is async. Clicking too fast before the frame fully renders causes the click to land on `body` (which does nothing useful). 4-5s is safe.
2. **Don't remove the `break`** — once you click the challenge, stop iterating. Clicking other frames is wasteful and can cause stray interactions.
3. **`disable_coop=True`** — Camoufox supports `disable_coop=True` which disables Cross-Origin-Opener-Policy, allowing direct clicks on cross-origin iframe content without needing `frame.locator()`. However, this weakens anti-fingerprint protection. Use the `page.frames` iteration pattern instead unless COOP causes actual breakage.
4. **Challenge may appear on page reload** — Some sites show the challenge after a `page.reload()` or navigation. Place the handler after any `goto()` or `reload()` that might trigger a challenge, not just after button clicks.
