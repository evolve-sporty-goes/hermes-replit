# Camoufox + Playwright CDP Compatibility

## Session: 2026-06-29

### Problem chain

1. `camoufox==0.4.11` broken on Playwright 1.61.0 (test env)
2. User requested migration to `cloverlabs-camoufox`
3. After install + `camoufox fetch`, same `setDefaultViewport` error persisted
4. Root cause: Playwright's JS driver sends `isMobile` in viewport — Firefox CDP rejects it

### Error transcript

```
playwright._impl._errors.Error: Browser.new_page: Protocol error (Browser.setDefaultViewport):
ERROR: failed to call method 'Browser.setDefaultViewport' with parameters {
  "browserContextId": "a5fe6804-...",
  "viewport": {
    "viewportSize": { "width": 1280, "height": 720 },
    "deviceScaleFactor": 1,
    "isMobile": false
  }
}
Found property "<root>.viewport.isMobile" - false which is not described in this scheme
```

### Fix — patch coreBundle.js

File: `<python_site_packages>/playwright/driver/package/lib/lib/coreBundle.js`

Locate `doUpdateDefaultViewport` (~line 45000):

**Before:**
```js
const viewport = {
  viewportSize: { width: ... },
  screenSize: ...,
  deviceScaleFactor: ... || 1,
  isMobile: !!this._options.isMobile   // <-- remove this line
};
await this._browser.session.send("Browser.setDefaultViewport", ...);
```

**After:**
```js
const viewport = {
  viewportSize: { width: ... },
  screenSize: ...,
  deviceScaleFactor: ... || 1
};
await this._browser.session.send("Browser.setDefaultViewport", ...);
```

Applied via `patch` tool (replace mode).

### Verification

```python
from camoufox.sync_api import Camoufox
with Camoufox(headless=True) as browser:
    ctx = browser.new_context(viewport={"width": 1280, "height": 720})
    page = ctx.new_page()
    page.goto("https://example.com", timeout=20000)
    print(page.title())  # "Example Domain" — works
```

### Notes

- The `isMobile` field is a Playwright protocol addition that never existed in Firefox's CDP
- Even `Camoufox(headless=True)` with no explicit viewport triggers this because Playwright applies a default
- `noViewport=True` doesn't help because Playwright still calls `setDefaultViewport` through `new_context()`
- Only `new_context(viewport=...)` without the JS patch fails — the patch is mandatory for any context creation
- The stderr lines `Skipping unknown patch audio:seed: N` and `Skipping unknown patch canvas:seed: N` are harmless but noisy — they indicate Camoufox's browserforge fingerprint seeds don't match the current Firefox build exactly. Cosmetic only.
