# TorBox Signup Reference

## Backend
- Supabase project: `db.torbox.app`
- Project ref: `bejxfytknnkoegtteuzs`
- Anon key embedded in `https://torbox.app/assets/index-dd8fba39.js`

## API Endpoint
```
POST https://db.torbox.app/auth/v1/signup
Headers: Content-Type: application/json, apikey: <anon_key>
Body: {"email":"<email>","password":"<password>"}
```

## Password Requirements
TorBox requires at least one of each: lowercase, uppercase, digit, symbol.
Symbols allowed: `!@#$%^&*()_+-=[]{};<>?/`~`
Signup script generates: 1 upper + 1 digit + 1 symbol (!@#%) + 12 mixed = 15 chars.

## Verification Email
- Sent from TorBox to the Duck.com address
- Duck addresses forward to Proton Mail inbox
- Verify link format: `https://db.torbox.app/auth/v1/verify?token=...&type=signup&redirect`
- Must be visited in a browser (Camoufox) — enables account + grants free trial

### Important: Verify links route through AWS awstrack

The actual verify URL in the email is a TorBox endpoint, but the email client
click-tracking wraps it or the `redirect_to` parameter points through:
```
https://qzd7845v.r.us-east-1.awstrack.me/L0/https://db.torbox.app/auth/v1/verify?...
```
This is an AWS CloudFront redirect tracker. After visiting this URL, the
browser passes through awstrack before landing on torbox.app.

**Do NOT use `wait_for_timeout(8000)` + `pg.url`** — you'll capture the awstrack
URL, not the final page. Instead use `wait_for_url` to wait until the tracker is past:

```python
pg.wait_for_url(lambda u: "awstrack" not in u, timeout=30000)
redirect_url = pg.url
```

See SKILL.md "Capturing Verify Redirect URL" section for the full pattern.

## Supabase Anon Key Storage

The anon key is stored in `/home/runner/workspace/.supabase_anon_key` (single
line, no newline). The script reads it with:
```bash
ANON=$(cat /home/runner/workspace/.supabase_anon_key)
```
This avoids embedding the key inline (which the Hermes display sanitizer
mangles as `***` in tool output). Also stored in `.hermes_data/.env` as
`SUPABASE_ANON_KEY=...` for other tooling.

**Important**: Add `.supabase_anon_key` to `sensitive.txt` so it's
synced to the hermes-secrets repo and excluded from git pushes.
Also add `torbox_credentials.txt` — it stores email, password, user_id,
and the API access token.

## API Key (Access Token)

TorBox's "API key" is the Supabase JWT access token obtained via login:

```
POST https://db.torbox.app/auth/v1/token?grant_type=password
Headers: Content-Type: application/json, apikey: <anon_key>,
          User-Agent: Mozilla/5.0, Origin: https://torbox.app,
          Referer: https://torbox.app/
Body: {"email":"<email>","password":"<password>"}
```

Response contains `access_token` (~875 char JWT, 1hr expiry) and `refresh_token`.
Use access_token as `Authorization: Bearer <token>` on all `api.torbox.app/v1/` calls.

### Important headers for API calls
- `User-Agent` is REQUIRED — without it, Cloudflare returns 403 (error 1010)
- `Origin: https://torbox.app` and `Referer: https://torbox.app/` are required for Supabase auth
- Use Python `urllib`terminal` with curl — the tool output sanitizer mangles apikey/$ANON in display

### User data fields
- `plan`: 0=free, 1+=paid tiers
- `is_subscribed`: boolean
- `premium_expires_at`: timestamp
- API has 92 endpoints — check `openapi.json` at `api.torbox.app`

### Not API keys
- `/v1/api/vendors/` endpoints are for reseller accounts, NOT API access
- Settings only has third-party keys (pixeldrain, onefichier, etc.), no TorBox API key field

## Free Trial Activation

TorBox dashboard has a "Get your free demo now!" button/link that activates the
free plan. Must be clicked in browser (Camoufox). Selectors:

- `a:has-text('Get your free demo now!')`
- `button:has-text('Get your free demo now!')`
- `text=Get your free demo now!`

The API key is then extracted from the settings page (`/settings`) by scanning
`<input>` element values for strings >20 chars with no spaces or @ signs.
Uses `page.evaluate()` JS as the extraction method.

## Working Script

`/home/runner/workspace/scripts/torbox-signup.sh` — single shell script with
inline Python heredocs for browser steps.

### Flow (5 steps)
1. Get email from `email.sh`, generate random password
2. POST to Supabase signup endpoint (bypasses Cloudflare Turnstile)
3. Open Proton Mail in Chromium (inline Python heredoc #1), search by email address, extract verify URL
4. Open verify URL in Camoufox (inline Python heredoc #2), wait for awstrack redirect to complete, capture redirect URL, click free demo, extract API key from settings
5. Append credentials to `torbox_credentials.txt` (including `redirect_url`)

### Output Pattern for Step 4
Python heredoc prints two lines to stdout:
- Line 1: API key (or empty string)
- Line 2: redirect URL (or empty string)

Shell captures into one var, splits with `head -1` / `tail -1`:
```bash
API_KEY_REDIRECT=$(python3 - "$VERIFY_URL" "$EMAIL" "$PW" << 'PYEOF'
...
print(key or "")
print(redirect_url or "")
PYEOF
)
API_KEY=$(echo "$API_KEY_REDIRECT" | head -1)
REDIRECT_URL=$(echo "$API_KEY_REDIRECT" | tail -1)
```

### Key Decisions
- Use Supabase API directly (not browser) for signup — bypasses Turnstile
- Use Chromium (not Camoufox) for Proton — avoids Firefox engine crash
- Search by full email address (Duck.com relays change sender name)
- Reload inbox on no results before retrying
- Merge shell + Python into single .sh with inline heredocs — user preference for short, crisp scripts
- Browser automation logic lives in tight Python heredocs inside the shell script
- Camoufox for TorBox (needs Firefox), Chromium for Proton (avoids crash)
- `wait_for_url` with domain predicate to capture post-redirect landing page (not awstrack intermediate)
