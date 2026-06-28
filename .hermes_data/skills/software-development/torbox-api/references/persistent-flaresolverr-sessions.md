# Persistent FlareSolverr Sessions

## Problem

When a signup pipeline requires solving Cloudflare on **multiple domains** (e.g., `db.torbox.app` for signup + `torbox.app` for dashboard), creating independent FlareSolverr requests means:
- Each request spawns a new headless Chrome
- Each solves Cloudflare independently (~5-15s each)
- Cookies from one domain aren't available to the next
- Total time: 3-4x longer than necessary

## Solution: Persistent Sessions

FlareSolverr supports a `"session"` parameter that reuses the same browser instance across requests. Pass a unique session ID on every call:

```json
{
  "cmd": "request.get",
  "url": "https://db.torbox.app/auth/v1/signup",
  "maxTimeout": 120000,
  "proxy": {"url": "socks5://127.0.0.1:9050"},
  "session": "torbox-tor-1719561234"
}
```

The first request creates the session and solves Cloudflare. Subsequent requests with the same session ID reuse the browser — cookies persist, and if the domain was already challenged, it's instant.

## Session Lifecycle

1. **Create** — first request with a new session ID spawns the browser
2. **Reuse** — subsequent requests with the same ID navigate in the same browser (cookies persist)
3. **Destroy** — explicitly destroy when done to free resources:
   ```json
   {"cmd": "session.destroy", "session": "torbox-tor-1719561234"}
   ```

## Bash Helper Pattern

```bash
SESSION_ID="torbox-tor-$(date +%s)"
FS_URL="http://127.0.0.1:8191/v1"

fs_request() {
  local CMD="$1" URL="$2"
  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'cmd': '$CMD',
    'url': '$URL',
    'maxTimeout': 120000,
    'proxy': {'url': 'socks5://127.0.0.1:9050'},
    'session': '$SESSION_ID'
}))
")
  curl -s -X POST "$FS_URL" \
    -H 'Content-Type: application/json' \
    -d "$PAYLOAD"
}

# Use throughout the pipeline
fs_request "request.get" "https://db.torbox.app/auth/v1/signup"
fs_request "request.get" "https://torbox.app/login"
fs_request "request.get" "https://torbox.app/settings"

# Cleanup
fs_request "session.destroy" "https://torbox.app"
```

## Cookie Extraction from Session Responses

```bash
COOKIE_STR=$(echo "$FS_RESP" | python3 -c "
import sys, json
r = json.load(sys.stdin)
cs = r.get('solution', {}).get('cookies', [])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs))
")

USER_AGENT=$(echo "$FS_RESP" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('solution', {}).get('userAgent', ''))
")
```

## When to Use Persistent vs Independent Sessions

| Scenario | Session Mode | Why |
|----------|-------------|-----|
| Single CF bypass (one domain) | Independent (no session param) | Simpler, auto-cleanup |
| Multi-domain pipeline (signup + dashboard) | **Persistent** | Cookies persist across domains, CF solved once per domain |
| Parallel signups | Independent or unique session IDs | Avoid cross-contamination |
| Debugging CF issues | Persistent | Inspect browser state between requests |

## Combining with Playwright

For interactive flows (login forms, button clicks), use FlareSolverr to get the initial CF cookies, then inject them into a Playwright session:

```python
# Get cookies from FlareSolverr persistent session
fs_cookies = [...]  # from fs_request response

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        td, executable_path=CH, headless=True,
        proxy={"server": "socks5://127.0.0.1:9050"}
    )
    # Inject all CF cookies from FlareSolverr
    for c in fs_cookies:
        ctx.add_cookies([{
            "name": c["name"], "value": c["value"],
            "domain": c.get("domain", "torbox.app"),
            "path": c.get("path", "/")
        }])
    # Now navigate freely — CF already solved
    pg = ctx.new_page()
    pg.goto("https://torbox.app/login")
```

## Pitfalls

1. **Session ID must be unique per pipeline run** — reuse of old IDs may attach to a dead browser. Use timestamp: `"torbox-tor-$(date +%s)"`
2. **Always destroy sessions** — FlareSolverr keeps browsers open. Leaked sessions consume memory.
3. **Session timeout** — FlareSolverr sessions expire after inactivity (default ~30 min). For long pipelines, make a keepalive request.
4. **Cookie domain scoping** — `db.torbox.app` cookies won't auto-apply to `torbox.app`. Inject both sets into Playwright.
5. **Tor circuit changes** — if Tor changes your exit IP mid-session, CF cookies from the old IP may be rejected. Use `SIGNAL NEWNYM` on Tor control port (9051) before starting a session for a fresh circuit, then keep it stable.
