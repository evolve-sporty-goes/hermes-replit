# CloudflareBypassForScraping Integration

Reference: [sarperavci/CloudflareBypassForScraping](https://github.com/sarperavci/CloudflareBypassForScraping)

## Overview

Open-source Cloudflare bypass server + library built on CloakBrowser. Version 2.0
(June 2026). Uses the same stealth Chromium but adds:
- `--enable-blink-features=FakeShadowRoot` for closed shadow DOM access
- Cookie caching (JSON file, TTL-based)
- Request mirroring (replays your HTTP request through the bypassed browser)
- FastAPI server for headless operation

## Key technique: FakeShadowRoot

Cloudflare Turnstile renders its checkbox inside a **closed** shadow root. Standard
Playwright cannot reach it. CloakBrowser's patched Chromium exposes
`el.fakeShadowRoot` natively via the Blink flag:

```python
# Launch arg (one-time setup)
args = ["--enable-blink-features=FakeShadowRoot"]
```

Then in JS:
```javascript
function find(root) {
  if (!root) return null;
  const direct = root.querySelector('input[type=checkbox]');
  if (direct) return direct;
  for (const el of root.querySelectorAll('*')) {
    const sr = el.fakeShadowRoot || el.shadowRoot;
    if (sr) { const r = find(sr); if (r) return r; }
  }
  return null;
}
```

## Solve flow

1. **Launch** — CloakBrowser with `FakeShadowRoot` flag
2. **Navigate** — `page.goto(url, wait_until="domcontentloaded")`
3. **Settle** — wait 5s for challenge scripts to load
4. **Detect** — check title/content for CF block markers
5. **Auto-solve** — non-interactive challenges resolve on their own (just wait)
6. **Manual click** — if still blocked, use FakeShadowRoot walker + `page.mouse.click()`
7. **Extract** — `context.cookies()` + `navigator.userAgent` (must be paired)

## Detection markers

```python
BLOCK_MARKERS = (
    "you have been blocked",
    "sorry, you have been blocked",
    "error 1020",
    "access denied",
)
# "cloudflare ray id" alone is NOT enough (legit footers have it)
```

## Cookie + User-Agent pairing

Cloudflare rejects cookies if the User-Agent doesn't match the one that earned them.
Always send both together:

```python
cookies = context.cookies()
user_agent = page.evaluate("navigator.userAgent")
# Use both in subsequent requests
```

## Concurrency

The repo uses `asyncio.Semaphore(MAX_CONCURRENT_BROWSERS)` to limit parallel
browser instances. For sync CloakBrowser, use a lock or queue pattern instead.

## Constants (from repo)

| Constant | Value | Purpose |
|---|---|---|
| `DEFAULT_TIMEOUT_MS` | 30000 | Page/navigation timeout |
| `CHALLENGE_SETTLE_SECONDS` | 5 | Wait before checking for CF |
| `RETRY_POLL_SECONDS` | 2 | Between retry attempts |
| `DEFAULT_MAX_RETRIES` | 10 | Max checkbox-click attempts |
| `CONTEXT_CLOSE_TIMEOUT_SECONDS` | 10 | Graceful close timeout |
| `MAX_CONCURRENT_BROWSERS` | 4 | Semaphore limit |

## Server setup (FastAPI)

The repo doubles as a **Cloudflare bypass proxy server**. Clone, install, and run:

```bash
git clone https://github.com/sarperavci/CloudflareBypassForScraping.git
cd CloudflareBypassForScraping
pip install -e .                              # editable install (deps: cloakbrowser, curl_cffi, fastapi, uvicorn, pydantic, pyvirtualdisplay)
python server.py --host 0.0.0.0 --port 8000  # or: uvicorn cf_bypasser.server.app:create_app --factory
```

**Docker** (preferred for production — handles Xvfb automatically):
```bash
docker run -p 8000:8000 ghcr.io/sarperavci/cloudflarebypassforscraping:latest
# Or build locally:
docker build -t cloudflare-bypass . && docker run -p 8000:8000 cloudflare-bypass
```

**Verify import works** before running:
```bash
python3 -c "from cf_bypasser.server.app import create_app; print('OK')"
```

### API endpoints

| Endpoint | Purpose | Key params/headers |
|---|---|---|
| `GET /cookies?url=` | Get clearance cookies + user-agent | `url`, `proxy` (query), `retries` |
| `GET /html?url=` | Get rendered HTML after bypass | `url`, `proxy`, `bypassCookieCache` |
| `GET /cache/stats` | Cache statistics | — |
| `POST /cache/clear` | Clear cookie cache | — |
| `/{any-path}` + `x-hostname` | Mirror any HTTP request | `x-hostname` (required), `x-proxy`, `x-bypass-cache` |

### Request mirroring usage

Point your scraper's base URL at the server, add `x-hostname`:

```bash
# GET
curl "http://localhost:8000/api/data" -H "x-hostname: cf-protected-site.com"

# POST with body
curl -X POST "http://localhost:8000/api/submit" \
  -H "x-hostname: cf-protected-site.com" \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}'

# With proxy
curl "http://localhost:8000/api/data" \
  -H "x-hostname: cf-protected-site.com" \
  -H "x-proxy: http://user:pass@proxy:port"
```

The server generates (or reuses cached) clearance cookies, then **replays your exact request** — method, path, query, headers, body — using `curl_cffi` (mimics Chrome's TLS/JA3 fingerprint) with CF cookies merged in.

### Cookie extraction usage

```bash
curl "http://localhost:8000/cookies?url=https://protected-site.com"
# Returns: {"cookies": {"cf_clearance": "..."}, "user-agent": "Mozilla/5.0 ..."}
```

### Architecture notes

- `cf_bypasser/core/bypasser.py` — `CloakBypasser` class: launches CloakBrowser, solves challenge, extracts cookies/HTML
- `cf_bypasser/core/mirror.py` — `RequestMirror` class: replays HTTP requests with bypassed cookies
- `cf_bypasser/server/app.py` — FastAPI app factory with lifespan-managed singletons
- `cf_bypasser/server/routes.py` — all route handlers
- `cf_bypasser/cache/cookie_cache.py` — JSON-file cookie cache with TTL
- `cf_bypasser/utils/security.py` — SSRF protection (blocks localhost/private IPs)
- Cookie cache is **per-worker** (not shared across uvicorn workers)
- `CLOAKBROWSER_AUTO_UPDATE=false` env var skips per-launch PyPI version check (use in prod)

### When to use this vs auto-solve

| Scenario | Approach |
|---|---|
| Simple CF challenge (non-interactive) | CloakBrowser auto-solves — just wait |
| Interactive Turnstile (visible checkbox) | FakeShadowRoot click |
| Clerk-managed Turnstile | Fix form state first → auto-solve |
| Need cookies for own HTTP client | Extract via `context.cookies()` or `/cookies` endpoint |
| High-volume scraping | Use the FastAPI server + cookie cache |
| Any HTTP method through CF | Use request mirroring (`x-hostname` header) |

### Known limitation: Clerk-managed Turnstile bypass fails

The bypass server **cannot solve Clerk-managed Turnstile** challenges. When calling
`/cookies?url=https://openrouter.ai/sign-up`, it returns:
```json
{"detail": "Failed to bypass Cloudflare protection"}
```

This is because Clerk renders Turnstile *after* form validation in React, and the
server's headless navigation doesn't fill/submit the form to trigger the challenge.
The Turnstile sitekey is also managed by Clerk (not visible in the page HTML).

**Workaround**: Pre-warm cookies by navigating in a real browser (Hermes browser
tool or Playwright) where form submission triggers Turnstile, then pass the resulting
cookies to the bypass server for caching.

### Clerk FAPI requires captcha token

Direct API calls to Clerk's FAPI endpoint fail without a valid Turnstile token:
```
POST https://clerk.openrouter.ai/v1/client/sign_ups
→ {"code": "captcha_missing_token"}
```

The token must come from a real browser solving the challenge. Cannot be forged,
bypassed, or obtained from the bypass server. The form must be submitted in a
browser environment where Turnstile can render and be solved.
