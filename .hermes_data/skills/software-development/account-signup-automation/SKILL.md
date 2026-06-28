---
name: account-signup-automation
description: |
  Automate account creation and email verification for web services.
  Covers: signup via API or browser, Proton Mail email verification via
  Chromium subprocess, credential storage. Uses email.sh for Duck.com
  addresses and ~/config.py for shared passwords.
---

# Account Signup Automation

Automated signup + email verification flow for web services (TorBox,
OpenRouter, etc.). Bypasses Cloudflare Turnstile where possible by
using the underlying API directly (e.g., Supabase Auth).

## Architecture

- **Signup**: Direct API call when the backend is known (Supabase,
  Firebase, etc.) — avoids browser-side captcha. Fallback: Camoufox
  for sites without a known API.
- **Email verification**: Playwright Chromium subprocess reads Proton
  Mail inbox. Camoufox and Playwright Chromium cannot share a process
  (Firefox engine crash on Proton's JS errors).
- **Credentials**: ~/config.py holds shared passwords
  (TORBOX_PASSWORD, PROTON_USERNAME, PROTON_PASSWORD).
- **Email**: email.sh generates Duck.com addresses via ddgep.vercel.app.

## Proton Mail Login Pattern

Always use this exact pattern for Proton login:

```python
pg.goto("https://account.proton.me/login", timeout=60000)
pg.wait_for_timeout(3000)
logged_in = False
try:
    if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
        logged_in = True
except:
    pass
if not logged_in:
    pg.locator("#username").fill(PROTON_USER)
    pg.locator("#password").fill(PROTON_PASS)
    pg.locator("button[type='submit']").click()
    pg.wait_for_timeout(10000)

# Always navigate to inbox explicitly — do NOT rely on Mail link click:
pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
pg.wait_for_load_state("networkidle")
pg.wait_for_timeout(3000)
```

Uses `account.proton.me/login` (not `mail.proton.me`), 60s timeout,
checks for existing session first, 10s after submit, then explicit inbox
navigation with `networkidle` wait before any inbox interaction.

### Common Pitfall 1: Exception Swallowing in Login Check

A buggy variant puts the credential fill inside the `except` block:

```python
# WRONG — do not do this
try:
    if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
        pg.locator("a:has-text('Mail')").first.click()  # if this throws...
except:
    pg.locator("#username").fill(...)  # ...this always runs
```

If the Mail link `.click()` throws (stale element, navigation race), the
`except` catches it and re-runs the login flow even though the user was
already authenticated — causing session conflicts or stuck states.

**Fix:** Separate the *check* from the *action*. Use a boolean flag, keep
the `try/except` around visibility only, then gate the login form on the
flag with a clean `if not logged_in:` — as shown in the canonical pattern
above.

### Common Pitfall 2: Missing Explicit Inbox Navigation

After the login block, do NOT rely on clicking the "Mail" link to reach
the inbox. If the page auto-redirected or the link click fails silently,
the search loop fires on `account.proton.me` instead of the inbox — the
`/` keyboard shortcut goes nowhere and all retries fail.

**Fix:** Always navigate explicitly to the inbox after the login check,
regardless of which branch was taken:

```python
if not logged_in:
    pg.locator("#username").fill(PROTON_USER)
    pg.locator("#password").fill(PROTON_PASS)
    pg.locator("button[type='submit']").click()
    pg.wait_for_timeout(10000)

# Always — not inside the if block:
pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
pg.wait_for_load_state("networkidle")
pg.wait_for_timeout(3000)
```

The `goto` is idempotent (refreshes if already there) and the
`networkidle` wait guarantees the inbox DOM is ready before the search
loop starts.

## Proton Mail Search Pattern

When searching for verification emails, search by the **actual email
address** (not generic keywords like "torbox"). If no results, reload
the page and retry:

```python
pg.keyboard.press("/")
pg.wait_for_timeout(800)
pg.keyboard.type(email, delay=20)
pg.keyboard.press("Enter")
pg.wait_for_timeout(4000)
items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
if items.count() > 0:
    items.first.click()
    pg.wait_for_timeout(2000)
    # proceed to extract verify link
else:
    pg.reload()
    pg.wait_for_load_state("networkidle")
    pg.wait_for_timeout(2000)
    # next retry iteration
```

## Supabase Auth Bypass

When a site uses Supabase Auth on the backend (check JS bundle for
`createClient`), call the API directly to bypass Cloudflare Turnstile:

```bash
curl -s -X POST "https://<project>.supabase.co/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: <anon_key>" \
  -d '{"email":"<email>","password":"<password>"}'
```

Extract the anon key from the site's JS bundle (look for
`eyJhbG...` JWT tokens).

**Custom Supabase domains** — Some sites use custom domains instead of `*.supabase.co`. TorBox uses `https://db.torbox.app`. To find the URL, search the site's JS bundle for `https://` URLs containing the domain, or use `firecrawl search "site:*.supabase.co <domain>"` to discover it.

## Credential Storage

- Append to `torbox_credentials.txt` (or service-specific file)
- NEVER overwrite — always use `>>`
- Format: `key=value` pairs, blank line between entries
- Include `verified=true/false` status
- Include `redirect_url=<url>` — the final URL after the verify link redirects (captured as `pg.url` after `goto(verify_url)`)

## Backup Before Edit

Before modifying any signup script, always create a backup:
```bash
cp scripts/torbox-signup.sh scripts/torbox-signup.sh.bak
```
This preserves the last-known-good version for rollback if the edit introduces a regression.

## Capturing Verify Redirect URL

When visiting a verification link in Camoufox, the browser follows redirects and lands on a final URL (e.g., `https://torbox.app/dashboard?verified=true`). Capture this for debugging and record-keeping.

### Pitfall: AWS awstrack intermediate redirects

Verification emails from some services (including TorBox) route clicks through an AWS tracking domain (`*.awstrack.me`) before redirecting to the actual destination. A naive `wait_for_timeout(8000)` + `pg.url` capture grabs the **intermediate** awstrack URL, not the final landing page:

```
WRONG — captures: https://qzd7845v.r.us-east-1.awstrack.me/L0/https://...
RIGHT — captures: https://torbox.app/dashboard?verified=true
```

**Fix:** Use `wait_for_url` with a URL-pattern predicate to explicitly wait until the redirect chain completes past the tracker:

```python
pg = browser.new_page()
pg.goto(verify_url, timeout=60000)
pg.wait_for_url(lambda u: "awstrack" not in u, timeout=30000)
redirect_url = pg.url  # now the REAL landing page
print(f"Verified: {redirect_url}", file=sys.stderr)
pg.close()
```

The `awstrack` check is domain-specific — adjust the predicate to whatever tracking domain the target service uses (e.g., `"click.example.com"`, `"redirect"`). If unknown, use `wait_for_url(lambda u: u != verify_url)` which waits until the URL from the original verify link.

### Full pattern (domain-specific wait)

```python
redirect_url = None
with Camoufox(headless=False, persistent_context=True, user_data_dir=td) as browser:
    pg = browser.new_page()
    pg.goto(verify_url, timeout=60000)
    pg.wait_for_url(lambda u: "awstrack" not in u, timeout=30000)
    redirect_url = pg.url  # final URL after all redirects
    pg.close()
    # ... rest of flow ...

print(key or "")
print(redirect_url or "")
```

Shell side — capture both lines, then split:
```bash
API_KEY_REDIRECT=$(python3 - "$VERIFY_URL" "$EMAIL" "$PW" << 'PYEOF'
...
PYEOF
)
API_KEY=$(echo "$API_KEY_REDIRECT" | head -1)
REDIRECT_URL=$(echo "$API_KEY_REDIRECT" | tail -1)
```

Then append `redirect_url=$REDIRECT_URL` to the credentials file.

## Hermes Tool Output Sanitizer Pitfall

When writing bash scripts with `$VARIABLE` references (like `$ANON` for
Supabase keys), the Hermes tool output display sanitizer replaces `$`
followed by variable names with `***`. **This is a display-only artifact —
the actual bytes on disk are correct.** Do NOT waste iterations "fixing"
lines that appear as `***` in terminal/grep output. Verify on-disk content
with Python binary read before diagnosing:

```python
python3 -c "
with open('script.sh','rb') as f: data=f.read()
for line in data.split(b'\n'):
    if b'apikey' in line: print('ON DISK:', line.decode())
"
```

To avoid the issue entirely: store secrets in a file (e.g.
`.supabase_anon_key`) and read with `ANON=$(cat .supabase_anon_key)` —
this avoids inline `$ANON` in curl headers that the sanitizer mangles in
display. The script works correctly at runtime regardless.

**Do NOT attempt base64/encoding workarounds** to sneak `$` past the
sanitizer. They don't help (the sanitizer catches them too) and they make
the script unreadable. Just accept the display artifact and verify
on-disk bytes with Python binary read if you need to confirm.

## TorBox API Key Extraction

TorBox does not have a separate "API key" — the **Supabase JWT access token** IS the API key for API usage. However, the TorBox web dashboard also exposes an API key in the settings page that third-party integrations (like Torrentio/Nuvio) use.

### Free trial activation

The dashboard shows a "Get your free demo now!" button/link that must be clicked in Camoufox to activate the free plan before the API key appears in settings. Selectors:
- `a:has-text('Get your free demo now!')`
- `button:has-text('Get your free demo now!')`
- `text=Get your free demo now!`

### API key from settings page

After trial activation, navigate to `/settings` and extract the key from `<input>` element values — look for strings >20 chars with no spaces or @ signs. Best method: `page.evaluate()` JS.

### Obtaining the access token

TorBox uses a custom Supabase domain: `https://db.torbox.app` (not `*.supabase.co`).

```python
import urllib.request, json

# Login via Supabase Auth (same anon key used for signup)
data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(
    "https://db.torbox.app/auth/v1/token?grant_type=password",
    data=data,
    headers={
        "Content-Type": "application/json",
        "apikey": anon_key,  # from .supabase_anon_key file
        "User-Agent": "Mozilla/5.0",  # required — 403 without it
        "Origin": "https://torbox.app",
        "Referer": "https://torbox.app/",
    }
)
with urllib.request.urlopen(req, timeout=15) as resp:
    token = json.loads(resp.read())["access_token"]
```

Key requirements:
- Must include `User-Agent` header (otherwise 403 with Cloudflare error 1010)
- Must include `Origin` and `Referer` headers
- The access token is ~875 chars, expires in 1 hour
- Use `urllib` not `curl` from Hermes terminal — the tool sanitizer mangles `$ANON`/apikey headers

### TorBox Supabase endpoints (confirmed)

| Action | Endpoint |
|--------|----------|
| Signup | `POST https://db.torbox.app/auth/v1/signup` |
| Login (password grant) | `POST https://db.torbox.app/auth/v1/token?grant_type=password` |
| Refresh token | `POST https://db.torbox.app/auth/v1/token?grant_type=refresh_token` |

### Available TorBox API endpoints (from openapi.json)

92 endpoints at `api.torbox.app`. Key ones:
- `GET /v1/api/user/me` — user info, plan status
- `GET /v1/api/user/subscriptions` — subscription status
- `GET /v1/api/torrents/mylist` — user's torrent list
- `GET /v1/api/torrents/checkcached` — check if torrent is cached
- `POST /v1/api/torrents/createtorrent` — create torrent download
- `GET /v1/api/webdl/hosters` — supported web download hosts
- `GET /v1/api/stats` — service statistics

### Free plan (plan: 0)

TorBox free plan provides API access with rate limits. The API key in settings
becomes available after clicking "Get your free demo now!" on the dashboard.
The `plan` field in user data indicates tier (0=free).

**Trial activation is IP/fingerprint-limited.** Fresh accounts from an IP that already used a trial get 403 "not eligible". Use a SOCKS5 proxy (`--proxy socks5://65.109.179.84:8443`) for the verify + trial steps to get a different IP. The browser tool does not support proxy config, so use curl for proxy-based verify and extract the access_token from the Location header.

### Vendor accounts are NOT API keys

The `/v1/api/vendors/` endpoints are for TorBox reseller/partner accounts (require `vendor_name` + `vendor_url`). These are unrelated to API access.

## TorBox Signup Script

`scripts/torbox-signup.sh` — single shell script covering the full pipeline: signup via API, verify email from Proton, visit verify link, get free trial, extract API key, append credentials. Uses inline Python heredocs for browser automation steps (Playwright/Chromium for Proton, Camoufox/Firefox for TorBox). See `references/torbox-signup.md` for full details.

| Script | Scope |
|--------|-------|
| `scripts/torbox-signup.sh` | Full pipeline (signup → verify → trial → API key) |
| `torbox.py` (root) | Full pipeline including Nuvio setup |

### Inline Python heredoc pattern

For shell scripts that need browser automation, embed Python in heredocs rather than separate files:

```bash
RESULT=$(python3 - "$ARG1" "$ARG2" << 'PYEOF'
import sys
arg1, arg2 = sys.argv[1], sys.argv[2]
# ... browser automation code ...
PYEOF
)
```

Key points:
- Use `<< 'PYEOF'` (quoted) to prevent shell variable expansion inside Python
- Pass args via `sys.argv` — `$VAR` inside unquoted heredocs gets mangled by the Hermes display sanitizer
- The heredoc Python runs as a subprocess — it cannot access shell variables directly

## User Preferences

- Password: when running standalone signup scripts, generate randomly
  (1 upper + 1 digit + 1 symbol + 12 mixed = 15 chars). When integrating
  with other services (Nuvio, etc.) that need a known password, use
  TORBOX_PASSWORD from ~/config.py
- Scripts must be MINIMAL — no flags, no -e/-c options, no helper
  functions beyond what's essential. Single-purpose, single-flow.
  If you're adding a flag, a menu, or a "convenience" feature, don't.
- email.sh is the ONLY email source — always `$(bash email.sh)`,
  no alternative inputs
- ~/config.py is the credential source — read TORBOX_PASSWORD,
  PROTON_USERNAME, PROTON_PASSWORD from it
- Credential files APPEND — never `>` (overwrite), always `>>`
- Keep scripts under 100 lines. Shorter is better.
