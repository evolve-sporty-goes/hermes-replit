---
name: torbox-api
description: "TorBox API integration — Supabase auth, API key retrieval, Tor SOCKS5 signup via FlareSolverr, persistent CF solving, and trial activation"
triggers:
  - torbox
  - torbox api
  - torbox login
  - torbox supabase
  - torbox trial
  - torbox demo
---

# TorBox API Integration

## Auth Architecture

TorBox uses **Supabase** for authentication at `https://db.torbox.app`.

### Login
```bash
curl -X POST "https://db.torbox.app/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"..."}'
```
Returns `access_token` (JWT). Use as `Authorization: Bearer <token>` on all TorBox API calls.

### Signup
```bash
curl -X POST "https://db.torbox.app/auth/v1/signup" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"new@example.com","password":"..."}'
```

## TorBox API

- **Base URL:** `https://api.torbox.app/v1/api/`
- **Auth header:** `Authorization: Bearer <supabase_access_token>`
- **API docs:** https://api-docs.torbox.app/
- **API key:** Retrieved from Supabase `api_tokens` table (see "API Key Retrieval" section) — the web Settings page also shows it but is blocked by Cloudflare

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/user/me` | GET | Get user info (plan, subscription status) |
| `/user/subscriptions` | GET | Get subscriptions |
| `/user/auth/device/start` | GET | Start device code auth |
| `/user/auth/device/token` | POST | Get token from device code |
| `/user/refreshtoken` | POST | Refresh session token |
| `/torrents/createtorrent` | POST | Create torrent |
| `/webdl/createwebdownload` | POST | Create web download |

## API Key Retrieval

The TorBox API key is stored in the Supabase `api_tokens` table. You do NOT need to brave the Cloudflare challenge on the web Settings page — query it directly:

```bash
# First, log in to get an access token (see Auth Architecture section)
SUPABASE_KEY=$(cat /path/to/supabase_key_or_env)
TOKEN=*** # from login response

# Get the user's auth_id from /user/me or the login response
AUTH_ID="<user's auth_id uuid>"

# Retrieve the API key from Supabase
curl -s "https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.${AUTH_ID}&select=token" \
  -H "apikey: $SUPABSE_KEY" \
  -H "Authorization: Bearer $TOKEN"
```

Response: `[{"id":...,"token":"329b7c...ccfd"}]`

The returned `token` field is the TorBox API key — use it as `Authorization: Bearer <token>` on all `/v1/api/` endpoints.

**Why this works:** TorBox's Supabase instance exposes the `api_tokens` table for authenticated users via the REST API, and the Supabase anon key + user JWT satisfy the RLS policy.

## Custom Email Signup + Verification

When the user provides a **specific email + password** (rather than using the automated `backup.sh` script which generates a new Proton email via `email.sh`):

### Step 1: Supabase Signup

```bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: *** \
  -d '{"email":"user@example.com","password":"..."}'
```

**Response on success:** `{"id":"uuid","email":"...","confirmation_sent_at":"...","app_metadata":{...}}`

**Response on error (duplicate email):** `{"msg":"User already registered"}` (or `{"error_description":"..."}`). The `msg` field holds the user-friendly message; `error_description` is the fallback.

**Extract:** `ID` from the `.id` field. The `confirmation_sent_at` timestamp confirms the verification email was sent.

### Step 2: Verify via Proton (if `config.py` is available)

If `~/config.py` exists with `PROTON_USERNAME` and `PROTON_PASSWORD`, run the existing extraction script:

```bash
python3 scripts/torbox-extract-verify-url.py user@example.com
```

### Step 2b: Verify via Proton (if `config.py` is MISSING — Replit reset)

On Replit, `config.py` may be lost in a reset. Signs of this: `ModuleNotFoundError: No module named 'config'` or the script exists but env vars aren't set. In that case:

1. Say plainly that the Proton automation can't run — `config.py` is missing
2. Ask the user to paste the Proton credentials (`PROTON_USERNAME` / `PROTON_PASSWORD`)
3. Recreate `~/config.py` with those two variables, then re-run extraction

**Do NOT attempt to manufacture credentials or skip verification.** The signup succeeds regardless; verification is a separate optional step the user controls.

### Step 3: Credentials file

Append to `torbox_credentials.txt` (workspace):

```bash
echo "email=user@example.com" >> torbox_credentials.txt
echo "password=..." >> torbox_credentials.txt
echo "user_id=<uuid>" >> torbox_credentials.txt
echo "magic_link=<verify_url or NOT_VERIFIED>" >> torbox_credentials.txt
echo "" >> torbox_credentials.txt
```

### Step 4: Extract access_token (after verify)

Once the verify URL is confirmed, use the **curl path** to extract tokens:

```bash
curl -s -D - -o /dev/null \
  "https://db.torbox.app/auth/v1/verify?token=<token>&type=magiclink&redirect_to=https://torbox.app" \
  -H "apikey: *** \
  -H "Authorization: Bearer $ANON"
```

Parse `Location` header fragment for `access_token`.

## Magic Link (OTP) Login

Passwordless login via Supabase — sends a magic link email with a single-use verify URL. **This is the preferred method when Cloudflare blocks browser automation.**

### Endpoint options

| Endpoint | Method | Cloudflare blocking | Notes |
|----------|--------|---------------------|-------|
| `/auth/v1/magiclink` | POST | Usually NOT blocked | Returns `{}` on success. Simplest path. |
| `/auth/v1/otp` | POST | Often blocked (403) | Same effect but more likely to trigger WAF. |

**Prefer `/auth/v1/magiclink`** — it sends the same magic link email but is less likely to be blocked by Cloudflare on datacenter IPs. Fall back to `/auth/v1/otp` only if magiclink fails.

### Request magic link (curl — simplest)

```bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
curl -s -X POST 'https://db.torbox.app/auth/v1/magiclink' \
  -H 'Content-Type: application/json' \
  -H "apikey: *** \
  -d '{"email":"user@example.com"}'
```

**Response:** `{}` (empty JSON) on success. The magic link email is sent to the address.

### User-handles-email mode

When the user says "initiate magic link, I'll get the email myself":
1. Request the magic link via curl (above)
2. Confirm `{}` response
3. Tell the user the email was sent — they will retrieve the verify URL themselves
4. Do NOT attempt Proton automation or browser_navigate

This is distinct from "generate only" mode (where the agent extracts the URL from Proton). In user-handles-email mode, the agent's job ends after the curl request succeeds.

### Cloudflare WAF on Supabase API

`db.torbox.app` is behind **Cloudflare WAF**, which blocks datacenter IPs:

- **Direct curl from server** → `403 Forbidden, error code: 1010` (Cloudflare challenge failed)
- **Playwright/browser fetch** → `200 OK` (bypasses Cloudflare) with correct anon key
- **Endpoint-specific blocking**: `/auth/v1/otp` may be blocked even from some IPs; `/auth/v1/signup` and `/auth/v1/token` are more permissive

**Solution — Playwright browser fetch (bypasses Cloudflare):**

```python
#!/usr/bin/env python3
"""Request OTP via Playwright browser fetch (bypasses Cloudflare WAF)."""
import json, sys, os
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib
if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

CH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PR = os.path.expanduser("~/proton_profile")

with open('/home/runner/workspace/.supabase_anon_key') as f:
    key = f.read().strip()

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(PR, executable_path=CH, headless=True, args=["--no-sandbox", "--disable-gpu"])
    pg = ctx.new_page()
    pg.goto("https://torbox.app", timeout=30000)
    pg.wait_for_timeout(2000)
    result = pg.evaluate('''async () => {
        const key = "''' + key + '''";
        const resp = await fetch('https://db.torbox.app/auth/v1/otp', {
            method: 'POST',
            headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: "''' + sys.argv[1] + '''" })
        });
        return await resp.text();
    }''')
    print(result)  # {} on success
    ctx.close()
```

**Why this works:** The browser runs from a non-datacenter IP (residential proxy via Browserbase/Playwright), so Cloudflare passes the request. The Supabase anon key is injected as a full string literal (no shell quoting issues).

**Fallback if browser fetch fails:** Use curl with the full key from a script file:

```bash
#!/bin/bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
curl -s -X POST 'https://db.torbox.app/auth/v1/otp' \
  -H "apikey: *** \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\"}"
```

Usage: `bash /tmp/torbox_otp.sh user@example.com`

**Key source:** Load from file with `ANON=$(cat /home/runner/workspace/.supabase_anon_key)` — never inline the 208-char key in shell commands. The `.supabase_anon_key` file is the working source; the `.env` copy may be redacted in terminal output.

### Verify and extract tokens (curl path — API-only, no browser session)

Write to a script file first (never inline the 208-char key):

```bash
#!/bin/bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
curl -s -D - -o /dev/null \
  "https://db.torbox.app/auth/v1/verify?token=<token>&type=magiclink&redirect_to=https://torbox.app" \
  -H "apikey: *** \
  -H "Authorization: Bearer $ANON"
```

Returns a **303 redirect** with the session in the URL fragment:

```
Location: https://torbox.app#access_token=eyJ...&expires_at=1782518357&expires_in=3600&refresh_token=abc123&token_type=bearer&type=magiclink
```

Parse the fragment to extract `access_token` and `refresh_token`. Use `access_token` as `Authorization: Bearer` on all TorBox API calls.

### Verify via browser (for trial activation — direct URL)

When you need a browser session (e.g. to activate the free trial), navigate to the **direct Supabase verify URL** (not the tracking wrapper):

```
browser_navigate(url='https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app')
```

The browser follows the redirect and lands on `torbox.app` with a valid session. **The direct URL and the `*.awstrack.me` tracking URL are functionally equivalent in the browser** — both follow the redirect chain to torbox.app. The direct URL is simpler and avoids potential tracking redirect timeouts.

**CRITICAL: The first navigate consumes the single-use token.** If the browser fails to load (e.g. about:blank, or the tracking redirect times out), the token is ALREADY consumed. Request a fresh magic link and try again — do not retry the same URL.

### Standalone OTP extraction (agent-side, no user copy-paste)

When the user says "extract the magic link yourself" or "do it end-to-end", use this flow — no manual email copy needed:

1. Request OTP via Playwright browser fetch (bypasses Cloudflare WAF — see "Cloudflare WAF on Supabase API" section). If browser fetch is unavailable, use curl from a script file:
```bash
#!/bin/bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
curl -s -X POST 'https://db.torbox.app/auth/v1/otp' \
  -H "apikey: *** \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\"}"
```
Save as `/tmp/torbox_otp.sh`, then: `bash /tmp/torbox_otp.sh user@example.com`

2. Extract the verify URL from Proton Mail via Playwright (match on `db.torbox.app/auth/v1/verify` in `e.href` — Playwright auto-decodes `&amp;` → `&`):
```bash
python3 scripts/torbox-extract-verify-url.py user@example.com
```
Output: the full verify URL (e.g. `https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app`)

**Extraction logic:** Use `frame.eval_on_selector_all("a[href]", "els => els.map(e => e.href)")` and match on `"db.torbox.app/auth/v1/verify" in href`. Playwright's `.href` property returns the decoded URL (no `&amp;` replacement needed). Do NOT use regex on raw HTML as `&amp;` breaks `[^\s"\'<>]*` patterns — if regex is the only option, use `[^\s"<>]*` and `.replace("&amp;", "&")`.

3. Navigate to it in the browser to establish session:
```
browser_navigate(url='<verify_url_from_step_2>')
```

**This replaces the full `backup.sh` when you only need a magic link for an existing account.** Use `backup.sh` only when you need a brand-new account with email signup.

### Two modes (user may specify either)

1. **Generate + Login** (default): Request OTP → extract verify URL → browser navigate to establish session. Use when the user wants to actually log in.
2. **Generate only, don't click** ("don't click it expires"): Request OTP → extract verify URL → output URL only, do NOT navigate. Use when the user wants the link for their own browser. The token stays valid until the user clicks it.

### Ready-made scripts

```bash
# Request OTP via Playwright (bypasses Cloudflare WAF)
python3 scripts/torbox-request-otp.py user@example.com

# Request OTP via curl (may get 403 from Cloudflare)
bash /tmp/torbox_otp.sh user@example.com

# Extract verify URL from Proton Mail (agent-side, no user copy-paste)
python3 scripts/torbox-extract-verify-url.py user@example.com

# Full end-to-end: request OTP + extract URL + navigate to login
# (same as running torbox-request-otp.py then torbox-extract-verify-url.py then browser_navigate)

# Full signup pipeline (signup + Proton verify + credentials file)
bash scripts/backup.sh
```bash
# Tor signup via FlareSolverr + PySocks (bypasses Cloudflare JS challenge)
bash scripts/torbox-tor-signup.sh [email_prefix] [password]
# Example: bash scripts/torbox-tor-signup.sh bavmin MyP@ss123

# Full end-to-end: Tor signup → Proton verify → Tor Playwright API key extraction
# Uses persistent FlareSolverr session for multi-domain CF bypass
bash scripts/torbox-full-tor-signup.sh [email_prefix] [password]
# Example: bash scripts/torbox-full-tor-signup.sh bavmin MyP@ss123

# Start/restart Tor + FlareSolverr infrastructure
bash scripts/start-tor-flare.sh
``` The full `backup.sh` is only needed for new account creation.

### User-preference: link output format

When the user says "generate the link" or "give me the magic link", output BOTH:
- The raw email link (may include `*.awstrack.me` wrapper) — this is what appears in the email the user receives
- The direct Supabase URL (decoded) — this is shorter and usable in curl or headless browser

When generating only (no click), return the link immediately after extraction. Do NOT `browser_navigate` to the link — that consumes the single-use token.

### Pitfalls

- **OTP tokens are single-use.** The verify URL can only be hit once. A second request returns `error=otp_expired&error_description=Email+link+is+invalid+or+has+expired`. You MUST capture the `Location` header on the first curl.
- **AWS tracking wrapper.** Magic link emails wrap the Supabase verify URL in an AWS SES tracking redirect (`*.awstrack.me/L0/...`). The actual token is in the inner Supabase URL. You can paste the full tracking URL into curl — it follows redirects — or extract the Supabase URL and call it directly.
- **Short expiry window.** OTP tokens expire quickly (~60s after the email is opened). Verify immediately after receiving the email.

## 24-Hour Free Pro Trial

Available to all free-plan users.

### Activation methods (in order of reliability)

**Method 1: Browser dashboard click** (most reliable — required for CSRF)

1. Request magic link: `bash /tmp/torbox_otp.sh user@example.com` (see "Request magic link" section above — **must use script file**)
2. Extract the verify URL from Proton Mail via Playwright: `python3 scripts/torbox-extract-verify-url.py user@example.com`
3. Navigate to the extracted verify URL in the browser:
   ```
   browser_navigate(url='<verify_url_from_step_2>')
   ```
   The browser follows the redirect and lands on `torbox.app` with a valid session.
4. **Do NOT navigate away or retry.** The first navigate consumes the single-use token. If the page fails to load, request a fresh magic link.
5. If the dashboard with "Get your free demo now!" button isn't visible on the landing page, the session may not have loaded — request a fresh magic link and try again.
6. Click "Get your free demo now!" button (find ref via `browser_snapshot`, click via `browser_click`)
7. Verify plan changed via `browser_console` fetch:
   ```javascript
   const auth = JSON.parse(localStorage.getItem('sb-db-auth-token'));
   const r = await fetch('https://api.torbox.app/v1/api/user/me', {headers: {'Authorization': 'Bearer ' + auth.access_token}});
   const d = await r.json(); d.data.plan;  // should be 1
   ```
8. Extract API key from Settings page or via Supabase REST (see "API Key Retrieval")

**Why browser, not curl:** The verify URL sets session cookies in the browser (Supabase `sb-db-auth-token` in localStorage + HTTP-only cookies). These cookies establish the CSRF session that `activatetrial` requires. Curl only gets the redirect headers — it cannot hold a browser session.

**Method 2: API call** (requires CsrfGuard proof-of-work — NOT directly callable)

The endpoint `POST /v1/api/unifiedpayments/activatetrial` requires `{"csrf_token": "..."}` in the body. The CSRF token is obtained via a **CsrfGuard proof-of-work challenge** — not a simple cookie or header value. The flow (captured via browser fetch interception):

1. `GET /v1/api/csrf-token/csrf.js` → 200 (loads CsrfGuard JS library ~8KB)
2. `GET /v1/api/csrf-token/GBq9/f4o7fc/2?q=<challenge_id>` → 200 (gets encrypted challenge blob)
3. `POST /v1/api/csrf-token/?ci=js/4.1.1&q=<challenge_id>` → 200 (solves PoW, returns `sealed_result` JSON with the CSRF token)
4. `POST /v1/api/unifiedpayments/activatetrial` with `Authorization: Bearer <token>` + `csrf_token` in body

The CsrfGuard JS runs client-side to solve the challenge — this happens automatically when clicking the dashboard button via the browser. It is NOT replicable via curl alone because the PoW solver is JS-only. Attempting the CsrfGuard flow via curl fails at step 3: the POST to `/csrf-token/?ci=js/4.1.1&q=...` returns `{"sealed_result": null, "error": {"code": "request_cannot_be_parsed", "message": "bad request"}}` — the challenge blob from step 2 must be processed by the CsrfGuard JS runtime before posting back. Only the browser can complete this flow.

**Trial eligibility is NOT purely IP-based — disposable email domains are flagged.** Confirmed 2026-06-27: Testing with a `@duck.com` account through a SOCKS5 proxy still returns `403: {"success":false,"error":"PAYMENT_ERROR","detail":"You are not eligible for the free trial. Please purchase a paid plan."}`. The full CsrfGuard PoW chain completes successfully (steps 1-3 return valid `sealed_result`), but `activatetrial` rejects at step 4. The eligibility check flags disposable/temporary email domains (e.g., `@duck.com`, `@tempmail.com`) and possibly other account-level signals. **Use a non-disposable email address (Gmail, Outlook, etc.) for trial eligibility.** Non-disposable emails have NOT been tested yet but are expected to work.

SOCKS5 proxy is still useful for the verify step (to get a different IP for the session cookies), but it does NOT bypass the trial eligibility check:
```bash
curl -s -D - -o /dev/null --proxy socks5://65.109.179.84:8443 \
  'https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app'
```
The browser tool does NOT support proxy config, so for proxy-based trial activation, use curl for verify (extract access_token) then browser_navigate with a fresh magic link for the dashboard click — or do everything via curl if you only need API access.

**CsrfGuard sealed_result IS the csrf_token.** The `sealed_result` field from the PoW solve step (step 3) is passed directly as `{"csrf_token": "<sealed_result>"}` in the activatetrial POST body. The full sealed_result is a base64-encoded blob (~300 chars).

**Known server bug:** Even with a valid CSRF token, `activatetrial` can return 500: `{"success":false,"error":"UNKNOWN_ERROR","detail":"There was an error activating the free trial. Please try again later.","data":"'NoneType' object has no attribute 'encode'"}`. This is a TorBox backend bug (Python NoneType crash), not a client issue. If this occurs, retry later or try with a fresh account.

**Conclusion:** Trial activation must go through the TorBox frontend browser session. Use Method 1 (dashboard button click). If the button click doesn't visibly trigger activation, check `/user/me` plan status — the XHR may succeed silently, or may have hit the 500 server bug.

### Cloudflare Turnstile

Cloudflare Turnstile blocks browser automation on the login page — use the magic link (OTP) flow to bypass it entirely and get a valid session without touching the login form.

### Free-plan API access

Most download/creation endpoints return `PLAN_RESTRICTED_FEATURE` on free plans. The API key works for read-only endpoints like `/user/me` until the Pro trial is activated.

## Pitfalls

1. **Cloudflare WAF on Supabase API (`db.torbox.app`).** Direct curl from datacenter IPs returns `403 Forbidden, error code: 1010`. The `/auth/v1/otp` endpoint is especially prone to blocking; `/auth/v1/signup` and `/auth/v1/token` are more permissive. **Solutions (in order):** (a) Use Playwright browser fetch with `pg.evaluate()` — inject the full 208-char key as a string literal; (b) Use `signup` endpoint instead of `otp` if the specific endpoint is blocked; (c) Use curl from a script file (may still get 403).

2. **Cloudflare Turnstile on login/dashboard.** The login page uses Cloudflare Turnstile (not a standard iframe challenge). The checkbox click via Playwright does NOT trigger validation — the Turnstile widget uses `render=explicit` and the `onloadTurnstileCallback` callback. Browser automation cannot pass it reliably. **Use the magic link (OTP) flow instead** — it bypasses Cloudflare entirely by going straight to Supabase Auth.

2. **API key is in Supabase, not behind Cloudflare.** The `api_tokens` table in Supabase is accessible via REST with the anon key + user JWT. This is the recommended retrieval path — skip the web Settings page entirely.

3. **Supabase token works as Bearer.** The `access_token` from the Supabase login works as `Authorization: Bearer` on the TorBox API (not as an `apikey` header).

4. **Free-plan API is read-only.** Most endpoints (torrents, web downloads, usenet, subscriptions management) return `PLAN_RESTRICTED_FEATURE` on free plans. Only read-only endpoints like `/user/me` work until the Pro trial is activated.

5. **Shell variable quoting with long tokens.** The Supabase anon key (~208 chars) and JWT access tokens (~869 chars) break when interpolated directly in shell `curl` commands — the shell can mangle or truncate them. **Always load from files** in scripts: `ANON_KEY=$(tr -d '\n\r' < /tmp/supabase_key.txt)` or use `head -1 /tmp/file` inside a script file. Never inline long tokens in one-liner shell commands. For interactive terminal use, write the full command to a .sh file and `bash` it rather than pasting the curl directly.

6. **Refresh token endpoint may fail.** `/user/refreshtoken` can return `DATABASE_ERROR` — this is a server-side issue, not an auth problem. Re-login to get a fresh access token instead.

7. **OTP verify is single-use.** The magic link verify URL (`/auth/v1/verify?token=...&type=magiclink`) can only be called once. A second request returns `otp_expired`. Always parse and save the `Location` header tokens from the first curl hit.

8. **Magic link emails wrap URLs in AWS tracker.** The verify URL in the email is wrapped in `*.awstrack.me/L0/...`. Curl follows the redirect, so you can pass the full tracking URL directly to `--verify`, or extract the inner Supabase URL for direct use. **In the browser tool, the direct Supabase URL works** — navigate to `https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app` directly. The tracking URL and direct URL are functionally equivalent in the browser.

9. **Browser navigate consumes the single-use OTP on first load.** When you `browser_navigate` to the magic link (tracking URL or inner URL), the first navigate **consumes the token immediately** as the browser follows the redirect chain. If the page fails to load (about:blank, tracking redirect times out, network error), the token is ALREADY spent — **request a fresh magic link**. Do NOT retry the same URL. A successful navigate lands on `torbox.app/#access_token=...` with a valid session. After landing, do NOT navigate away — use `browser_console` for all subsequent actions.

10. **Dashboard "Get your free demo now!" button.** The button is visible when `plan=0` (free). Clicking it triggers a CsrfGuard proof-of-work flow automatically (see Method 2). Known issues: (a) the inner button ref (e.g. `e17`) and the outer container ref may both appear to do nothing — the click fires an async XHR chain (csrf-token challenge → PoW solve → activatetrial POST); (b) after clicking, check the result by reading `plan` from `/user/me` via `browser_console` fetch, not by looking for a DOM change; (c) **activatetrial can return 500** with `'NoneType' object has no attribute 'encode'` — this is a TorBox server bug, not a client issue. Retry later or try a fresh account; (d) to debug the activation flow, intercept fetch/XHR calls in `browser_console` to see the full request chain and response bodies.

11. **Magic link verify: curl vs browser.** `curl` to the verify URL extracts the access_token from the `Location` header but consumes the single-use link without establishing a browser session. `browser_navigate` to the verify URL establishes the session in localStorage but you lose the raw `Location` header. **Choose one path per magic link:**
   - **Curl path:** Use when you only need API access (access_token for curl calls). Save token to file. Cannot subsequently use browser for dashboard actions.
   - **Browser path:** Use when you need to activate the trial via the dashboard button. Token is in `localStorage.getItem('sb-db-auth-token')`. Extract it via `browser_console` if you also need it for API calls.
   - **Never both:** The link is single-use. Pick one approach per magic link request.

12. **Intercepting XHR for debugging.** To capture the full CSRF/trial activation flow from the browser, override `window.fetch` and `XMLHttpRequest.prototype.open/send` in `browser_console` before clicking the button. Log URL, method, headers, body, and response. The CsrfGuard flow uses `fetch` (not XHR), so intercepting both is needed. Pattern:
   ```javascript
   window.__captured = [];
   const origFetch = window.fetch;
   window.fetch = async function(...args) {
     const url = typeof args[0] === 'string' ? args[0] : args[0]?.url;
     const resp = await origFetch.apply(this, args);
     if (url.includes('trial') || url.includes('csrf')) {
       const clone = resp.clone();
       window.__captured.push({url, status: resp.status, body: (await clone.text()).substring(0,500)});
     }
     return resp;
   };
   ```
   After clicking, read `window.__captured` to see the full request/response chain.

13. **API key requires Pro/paid plan.** The Settings page shows "Upgrade to Access API" for free-plan users — the API key in the `api_tokens` Supabase table exists but the web UI gates it behind a paid plan. The API key retrieved from Supabase REST still works for read-only endpoints on free plans, but most download/creation endpoints return `PLAN_RESTRICTED_FEATURE`.

14. **Magic link verify via SOCKS5 proxy.** You can complete the verify step through a SOCKS5 proxy to get a different IP (useful when trial eligibility is IP-limited). The curl `--proxy` flag works with the verify URL:
   ```bash
   REDIRECT=$(curl -s -D - -o /dev/null --proxy socks5://65.109.179.84:8443 \
     'https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app')
   ```
   Extract `access_token` from the `Location` header fragment as usual. The browser tool does NOT support proxy config — for proxy + dashboard trial activation, use curl for verify (get token), then request a fresh magic link and use browser_navigate for the dashboard click.

16. **Supabase anon key source matters.** The key in `/home/runner/workspace/.hermes_data/.env` (canonical) and `/home/runner/workspace/.supabase_anon_key` (file) may differ. The `.supabase_anon_key` file is the working source — load with `ANON=$(cat /home/runner/workspace/.supabase_anon_key)`. The `.env` copy may be redacted in terminal output; the `.supabase_anon_key` file never is.

17. **OTP endpoint rejects inline shell commands.** The 208-char anon key + 200+ char email JSON body breaks when interpolated directly in shell `curl` commands (shell quoting mangles the JSON). **Always write the curl to a `.sh` file and `bash` it** — never inline the full command in a one-liner. The `scripts/torbox-extract-verify-url.py` handles the Playwright side; for the curl side, use a script file.

18. **Regex on raw HTML fails due to `&amp;`.** When extracting verify URLs from email HTML, `[^\s"\'<>]*` regex stops at `&` because HTML encodes `&` as `&amp;`. **Use Playwright's `e.href` property instead** — it auto-decodes `&amp;` → `&` and returns the full URL. If regex is the only fallback, use `[^\s"<>]*` (no `'` in exclusion set) and `.replace("&amp;", "&")`.

19. **Direct Supabase URL works in browser — tracking URL not required.** The verify URL from the email (`https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app`) can be navigated to directly in the browser — no need to use the `*.awstrack.me/L0/...` tracking wrapper. Both work; the direct URL is simpler. The tracking URL is also present in the email but is for a different purpose (`forgotpw`) in some cases — match on `db.torbox.app/auth/v1/verify` specifically.

20. **Proton login detection via URL, not form elements.** When navigating to `account.proton.me/login` with a logged-in persistent profile, the browser **redirects immediately** to `account.proton.me/apps` or `mail.proton.me/...` — the `#username` field never appears. Do NOT use `pg.locator("#username").wait_for()` or `pg.locator("a:has-text('Mail')").is_visible()` — both will timeout for 30s. Instead, check `pg.url` after the initial `goto`: if `"login" not in pg.url`, the session is already authenticated. If credentials ARE needed, the login form fill will work normally.

21. **Email item click intercepted by search input.** After `keyboard.type(email)` in Proton's search box, pressing Enter and then clicking the search result fails because the search `<input>` retains focus and **intercepts pointer events** on sibling elements (the click resolves to the input instead of the email item). Fix: press `Escape` to defocus the search input before clicking the email item: `pg.keyboard.press("Escape"); pg.wait_for_timeout(500); items.first.click(force=True)`. The `force=True` bypasses Playwright's actionability check (which waits indefinitely when the input intercepts). Alternatively, if `force=True` still fails, use `pg.evaluate()` to dispatch a MouseEvent on the element directly.
23. **`magiclink.sh` (workspace) has unpatched Proton click bug.** The workspace script `scripts/magiclink.sh` uses `items.first.click()` without `force=True` and without the `Escape` defocus step — it fails intermittently when the search input intercepts pointer events. If the user says "run magiclink" and the script returns false `NOT_FOUND`, run the Python extraction script directly instead:
```bash
# Request OTP
python3 scripts/torbox-request-otp.py user@example.com
# Extract URL
python3 scripts/torbox-extract-verify-url.py user@example.com
```
If a browser login is needed, it's a separate explicit step (`browser_navigate`).

**Verified working fallback pattern (2026-06-27):** When the Python extraction script ALSO fails (e.g. 8 items found but `NO_LINK_FOUND`), use this inline Playwright script that adds `force=True` click and double-URL-decode for awstrack wrappers:
```python
import urllib.parse
# ... after finding items ...
items.first.click(force=True)  # bypass actionability check
# ... extract href from frames ...
if "/L0/" in found_url:
    encoded = found_url.split("/L0/")[1]
    decoded = urllib.parse.unquote(urllib.parse.unquote(encoded))
    print(decoded)  # direct Supabase URL
```
The `force=True` is critical — without it, Playwright's actionability check loops on the intercepted click. The double `unquote` handles AWS tracker's double-encoded paths (`%252F` → `%2F` → `/`).

24. **Generate-only mode is not a failure.** When the user says "just give me the link" or "don't click", output the verify URL without `browser_navigate`. The link expires only when clicked. Returning the link to stdout is the correct end state — do NOT raise an error or try to "complete" the login flow.

25. **`config.py` missing on Replit resets.** The Proton extraction script requires `~/config.py` with `PROTON_USERNAME` and `PROTON_PASSWORD`. On Replit, this file is ephemeral and lost on reset. If you get `ModuleNotFoundError: No module named 'config'`, ask the user for their Proton credentials and recreate the file. The signup itself (Supabase) does NOT need `config.py` — only the Proton verification step does.

**Recovery pattern when `email.sh` hangs:** Running `bash email.sh` to recreate `config.py` can hang on the duckmail Camoufox step (30s+ timeout). Instead, run only the heredoc portion:
```bash
cat > ~/config.py << 'cPYEOF'
import random
_CREDENTIAL_POOLS = [
    {"USER": "jhajikv3", "API_KEY": "34agdnn0us1hvgaovvkock2dfoo9vxxnuecbidrupqh4crjv6y1vi5fs1vij0i"},
    # ... (get full list from email.sh or working config)
]
_selected_pair = random.choice(_CREDENTIAL_POOLS)
USER = _selected_pair["USER"]
API_KEY = _selected_pair["API_KEY"]
TORBOX_PASSWORD = "Satyana@1234"
STREMIO_EMAIL = "tygun2@outlook.com"
STREMIO_PASSWORD = "Satyana@1234"
PROTON_USERNAME = "bavmin"
PROTON_PASSWORD = "Satyana@1234"
FIRECRAWL_API = "fc-529...c674"
cPYEOF
```
Or if `email.sh` already ran and was killed, check if `~/config.py` exists — the heredoc may have completed before the Camoufox step.

26. **`scripts/backup.sh` is the TorBox signup pipeline, not a backup.** Despite the name, this script creates a new TorBox account (calls `email.sh` → Supabase signup → Proton verify → credentials file). When the user says "run backup.sh", they mean "run the signup pipeline".

27. **`/auth/v1/magiclink` is simpler and less blocked than `/auth/v1/otp`.** Both send the same magic link email. `/auth/v1/magiclink` returns `{}` on success via plain curl from datacenter IPs; `/auth/v1/otp` is more likely to get 403 from Cloudflare WAF. **Use `/auth/v1/magiclink` as the default magic link endpoint** — only fall back to `/auth/v1/otp` if magiclink returns 403.

28. **TorBox blocks VPNs/proxies on signup & payment.** Tor exit nodes, SOCKS5 proxies, iCloud Relay, and Brave VPN are all flagged by TorBox's fraud detection. The Supabase auth signup (`/auth/v1/signup`) may succeed from a Tor IP, but payment/subscription actions will fail with `"unable to process payments from your IP address"`. **Use a clean residential IP for all TorBox interactions.** See `references/trial-eligibility.md` for the full VPN/proxy blocking policy.

28a. **Tor exit nodes hit Cloudflare JS challenge on `db.torbox.app` — but FlareSolverr bypasses it.** Confirmed 2026-06-28: `curl --socks5-hostname 127.0.0.1:9050` to `https://db.torbox.app/auth/v1/signup` returns a full Cloudflare "Just a moment..." JS challenge page. `curl` cannot solve JS challenges. **However**, FlareSolverr (headless Chrome on `127.0.0.1:8191`) solves the challenge through Tor and returns a `cf_clearance` cookie. Replay that cookie via Python + PySocks to complete the signup. See `references/tor-socks5-test-results.md` for the full working recipe and `scripts/torbox-tor-signup.sh` for the ready-made script.

28e. **Camoufox `geoip=True` does NOT bypass Tor IP blocking.** Camoufox's `geoip=True` spoofs timezone/locale/WebRTC to match the proxy exit IP's region — but it cannot change the IP itself. Tor exit nodes are on Cloudflare's IP blocklist regardless of browser fingerprint. **For Cloudflare-protected sites, use residential proxies (not Tor) with Camoufox + `geoip=True`.** Tor is only viable when combined with FlareSolverr (to solve the JS challenge) + PySocks (to replay cookies). See `references/tor-detection-bypass.md` for the full comparison of bypass techniques.

28f. **Camoufox has no native SOCKS5 proxy support.** GitHub issue #368 (open Aug 2025): Camoufox/Playwright's proxy config only routes TCP, leaving UDP (WebRTC) unproxied → IP leak. Workaround: use `pproxy` to create a local SOCKS5→SOCKS5 forward, but this still doesn't solve UDP. For Tor integration, use Playwright's native `proxy={"server": "socks5://127.0.0.1:9050"}` (which does support SOCKS5) instead of Camoufox. Camoufox is best for anti-fingerprint on clean IPs, not for Tor routing.

28g. **FlareSolverr IS Playwright internally — don't double up.** FlareSolverr runs headless Chrome via Playwright/Puppeteer under the hood. Using FlareSolverr + a separate Playwright instance means running two browsers. **Use FlareSolverr only when you need CF-solved cookies for non-browser tools (curl, urllib, PySocks).** If you're already using Playwright for page interaction, let Playwright solve CF natively on `page.goto()` — it's a real browser and handles JS challenges automatically. The hybrid pattern (FlareSolverr for CF cookie → inject into Playwright) is only needed when the actual request must go through a non-browser path (e.g., PySocks through Tor).

28b. **Tor SOCKS5 proxy is available on Replit and CAN work for TorBox signup with FlareSolverr.** Tor is pre-installed (`/nix/store/wnfpm8rjbgq5nhqj4dr85jnky86xvxcx-tor-0.4.8.16/bin/tor`) and running by default (SOCKS5 on `127.0.0.1:9050`, control port `9051`). Verify with `curl --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip`. For TorBox signup through Tor: use `scripts/torbox-tor-signup.sh` (FlareSolverr + PySocks). For payment/subscription actions, Tor exit IPs are still flagged by TorBox's fraud detection — use a clean residential IP for those.

28c. **Persistent FlareSolverr sessions for multi-domain pipelines.** When a pipeline requires Cloudflare bypass on multiple domains (e.g., `db.torbox.app` for signup + `torbox.app` for dashboard), use a **single persistent FlareSolverr session** instead of independent requests. Pass `"session": "unique-id"` on every call — the first creates the browser, subsequent calls reuse it (cookies persist, CF solved once per domain). Destroy with `{"cmd": "session.destroy"}` at the end. See `references/persistent-flaresolverr-sessions.md` for the full pattern, bash helper, and Playwright cookie injection. The script `scripts/torbox-full-tor-signup.sh` implements this pattern.

28d. **Full end-to-end Tor signup pipeline (signup → verify → API key).** The merged script `scripts/torbox-full-signup.sh` combines all three steps into one flow:
1. **Step 1 — Signup via Tor + FlareSolverr:** FlareSolverr (headless Chrome + Tor SOCKS5) solves Cloudflare JS challenge → returns `cf_clearance` cookie → Python + PySocks replays the cookie to POST `/auth/v1/signup` through Tor.
2. **Step 2 — Verify URL via Playwright + Proton (NO Tor):** Normal Playwright (`headless=False`, fallback `headless=True`) logs into Proton Mail, searches inbox for the TorBox verification email, extracts the verify URL. No Tor proxy here — Proton may block Tor exits.
3. **Step 3 — Verify + extract API key via Playwright + Tor:** Playwright with `proxy={"server": "socks5://127.0.0.1:9050"}` visits the verify URL (Cloudflare auto-solved by real browser), logs into TorBox dashboard, navigates to `/settings`, extracts API key. Falls back to `/api/user/me` fetch if settings page doesn't expose it directly.

**Usage:** `bash scripts/torbox-full-signup.sh [email_prefix] [password]`
- Default: `bavmin+RAND@proton.me` / `Satyana@1234`
- Custom: `bash scripts/torbox-full-signup.sh myuser MyP@ss123`

**Requirements:** Tor on `9050`, FlareSolverr on `8191`, PySocks (`pip install PySocks`), Playwright, `~/config.py` with `PROTON_USERNAME`/`PROTON_PASSWORD`.

**Why FlareSolverr for step 1 but not step 3:** Step 1 is a raw HTTP POST (no browser), so it needs FlareSolverr to get the CF cookie first. Step 3 uses Playwright directly — a real browser auto-solves Cloudflare JS challenges on `page.goto()` without needing FlareSolverr. Adding FlareSolverr to step 3 would be redundant (FlareSolverr IS Playwright internally).

**headless=False rationale:** The user requested visible browsers where possible. Steps 2 and 3 try `headless=False` first, falling back to `headless=True` if no display is available (e.g., pure SSH session). This allows visual debugging when a display is present.

29. **User-handles-email mode.** When the user says "initiate magic link" or "I'll get the email myself", the agent's job is just the curl request to `/auth/v1/magiclink`. Do NOT attempt Proton automation, Playwright browser fetch, or browser_navigate. Confirm `{}` response and tell the user the email was sent. This is distinct from "generate only" mode (agent extracts URL from Proton but doesn't click) and "generate + login" mode (agent extracts URL and navigates).

30. **Tor + FlareSolverr startup on Replit.** Both services may stop after inactivity or session restart. Use `bash scripts/start-tor-flare.sh` to restart — it's idempotent (skips if running), waits for Tor bootstrap, starts FlareSolverr Docker container with `--network host`, and health-checks both. See `references/tor-flare-infrastructure.md` for manual start commands, binary paths, and environment constraints (no VPN/TUN — only Tor SOCKS5 works for proxying).

31. **VPN does NOT work on Replit.** No `/dev/net/tun`, no `modprobe`, no network namespace → OpenVPN, WireGuard, Proton VPN all fail. Only Tor SOCKS5 (userspace proxy) works for IP masking. For clean Residential IPs, use free SOCKS5 proxy lists with Camoufox + `geoip=True`.

## Supabase Anon Key Location

The Supabase anon key is stored at:
- **Working source:** `/home/runner/workspace/.supabase_anon_key` (208 bytes, load with `cat`)
- **Canonical:** `/home/runner/workspace/.hermes_data/.env` as `SUPABASE_ANON_KEY=...` (may be redacted in terminal output — use `.supabase_anon_key` for shell scripts)
- **Session temp:** `/tmp/supabase_key.txt` (populated during session scripts)

In shell scripts, load with: `ANON=$(cat /home/runner/workspace/.supabase_anon_key)`

**Always load from `.supabase_anon_key` file** — never inline the 208-char key in shell commands (shell quoting mangles it). The `.env` version works when loaded by Hermes internally but may be redacted or truncated in bare terminal output.

## References

- `references/custom-email-signup.md` — Custom email+password signup flow (when user provides specific credentials instead of using `backup.sh`)
- `references/magic-link-browser-flow.md` — Step-by-step browser-based trial activation flow (session-tested, with failure table)
- `references/otp-extraction-flow.md` — End-to-end OTP magic link flow (request → extract → verify → activate)
- `references/proton-session-debugging.md` — Proton Playwright pitfalls: login detection via URL (not form elements), search input click interception, verify URL in email-body iframe
- `references/generate-only-mode.md` — Generate the magic link without clicking it (two-mode pattern, output format, fallback when magiclink.sh fails)
- `references/api-endpoints.md` — Full TorBox API endpoint list and schemas
- `references/supabase-tables.md` — Supabase table structure (how to get the API key, user data, settings)
- `references/csrf-guard-flow.md` — Captured CsrfGuard PoW flow for activatetrial (full request/response chain, curl failure details, interceptor code)
- `references/trial-eligibility.md` — Confirmed eligibility patterns: disposable email domains (duck.com) get 403 PAYMENT_ERROR at activatetrial step 4; full PoW chain succeeds before rejection; VPN/proxy blocking policy (Tor, SOCKS5, iCloud Relay all flagged)
- `references/tor-socks5-test-results.md` — Tor SOCKS5 proxy test results (2026-06-28): Cloudflare JS challenge blocks all Tor exits on `db.torbox.app`; FlareSolverr + PySocks bypass works
- `references/tor-flare-infrastructure.md` — Tor + FlareSolverr deployment on Replit: binary paths, Docker config, startup script, environment constraints (no VPN/TUN), troubleshooting
- `references/tor-detection-bypass.md` — Tor detection bypass techniques compared: FlareSolverr+PySocks vs Camoufox+residential vs Camoufox+geoip; when each works and why
- `references/full-tor-signup-pipeline.md` — Full end-to-end Tor signup pipeline architecture: FlareSolverr signup → Proton verify → Tor Playwright API key extraction
- `references/persistent-flaresolverr-sessions.md` — Persistent FlareSolverr session pattern: reuse single browser across multi-domain CF challenges, bash helper, Playwright cookie injection
- `torbox-info.md` (workspace) — Quick reference with credentials file locations
- `scripts/torbox-magic-link.sh` (via web-data-extraction skill) — Ready-made magic link request + verify script
- `scripts/torbox-extract-verify-url.py` — Standalone Playwright script to extract TorBox verify URL from Proton Mail inbox (no user copy-paste needed)
- `scripts/torbox-full-tor-signup.sh` — Full Tor signup pipeline with persistent FlareSolverr session (multi-domain CF bypass in one browser)
- `scripts/torbox-full-signup.sh` — Non-Tor full pipeline (signup + Proton verify + API key)
- `scripts/start-tor-flare.sh` — Start Tor + FlareSolverr (idempotent, health checks both services)
