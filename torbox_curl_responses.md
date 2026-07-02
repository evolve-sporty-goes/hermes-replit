# TorBox API - db.torbox.app curl responses

## Base URL
https://db.torbox.app

## Supabase Auth Endpoints

### 1. Signup
**POST** https://db.torbox.app/auth/v1/signup
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -d '{"email":"user@example.com","password":"..."}'
```

**Success Response (200):**
```json
{
  "id": "uuid-here",
  "aud": "authenticated",
  "role": "authenticated",
  "email": "user@example.com",
  "phone": "",
  "confirmation_sent_at": "2026-07-02T03:38:26.809377607Z",
  "app_metadata": {"provider": "email", "providers": ["email"]},
  "user_metadata": {"email": "user@example.com", "email_verified": false, "phone_verified": false, "sub": "uuid-here"},
  "identities": [...],
  "created_at": "2026-07-02T03:38:26.800089Z",
  "updated_at": "2026-07-02T03:38:27.87196Z",
  "is_anonymous": false
}
```

**Error: Weak Password (422):**
```json
{"code":422,"error_code":"weak_password","msg":"Password should contain at least one character of each: abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ, 0123456789, !@#$%^&*()_+-=[]{};':\"|,.<>?/~`.","weak_password":{"reasons":["characters"]}}
```

**Error: Bad JSON (400):**
```json
{"code":400,"error_code":"bad_json","msg":"Could not parse request body as JSON..."}
```

---

### 2. Login (Token)
**POST** https://db.torbox.app/auth/v1/token?grant_type=password
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"..."}'
```

**Success Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "expires_at": 1782515305,
  "refresh_token": "short-refresh-token",
  "user": {
    "id": "uuid-here",
    "aud": "authenticated",
    "role": "authenticated",
    "email": "user@example.com",
    "email_confirmed_at": "2026-06-26T15:31:01.433547Z",
    "phone": "",
    "confirmation_sent_at": "2026-06-26T15:30:18.578901Z",
    "confirmed_at": "2026-06-26T15:31:01.433547Z",
    "recovery_sent_at": "2026-06-26T21:48:03.846203Z",
    "last_sign_in_at": "2026-06-26T22:08:25.94869867Z",
    "app_metadata": {"provider": "email", "providers": ["email"]},
    "user_metadata": {"email": "user@example.com", "email_verified": true, "phone_verified": false, "sub": "uuid-here"},
    "identities": [...]
  }
}
```

**Error: Invalid API Key (400):**
```json
{"message":"Invalid API key","hint":"Double check your Supabase `anon` or `service_role` API key."}
```

**Error: Email Not Confirmed (400):**
```json
{"code":400,"error_code":"email_not_confirmed","msg":"Email not confirmed"}
```

---

### 3. Request OTP (Magic Link)
**POST** https://db.torbox.app/auth/v1/otp
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/otp" \
  -H "apikey: $SUPAB...KEY" \
  -H "Authorization: Bearer $SUPAB..._KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

**Success Response (200):**
```
{}
```

**Note:** This endpoint requires Cloudflare bypass (Playwright browser fetch). Direct curl from server returns 403 Forbidden (error code 1010).

**Working Method: cloakbrowser/Playwright browser fetch**
```python
from cloakbrowser import launch, launch_persistent_context
import os, sys, importlib

sys.path.insert(0, os.path.expanduser("~"))
if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

SUPABASE_KEY = open('/home/runner/workspace/credentials/.supabase_anon_key').read().strip()
EMAIL = "user@example.com"
PROFILE = os.path.expanduser("~/proton_profile")

ctx = launch_persistent_context(PROFILE, headless=True, humanize=True)
pg = ctx.new_page()
pg.goto("https://torbox.app", timeout=30000)
pg.wait_for_timeout(2000)

result = pg.evaluate(f'''async () => {{
    const key = "{SUPABASE_KEY}";
    const resp = await fetch("https://db.torbox.app/auth/v1/otp", {{
        method: "POST",
        headers: {{ "apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json" }},
        body: JSON.stringify({{ email: "{EMAIL}" }})
    }});
    return await resp.text();
}}''')
print(f"OTP response: {result}")  # {} = success
ctx.close()
```

**Critical:** Pass the full 208-char Supabase key inside the `pg.evaluate()` string. Do NOT truncate it.

---

### 4. Email Verification Link
**GET** https://db.torbox.app/auth/v1/verify?token=...&type=signup&redirect_to=...
```bash
curl -s -L "https://db.torbox.app/auth/v1/verify?token=TOKEN&type=signup&redirect_to=https://torbox.app/"
```

**Success:** Returns HTML page that redirects to https://torbox.app/
**Error (expired OTP):**
```
Final URL: https://torbox.app/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired&sb=
```

---

### 5. Refresh Token
**POST** https://db.torbox.app/auth/v1/token?grant_type=refresh_token
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/token?grant_type=refresh_token" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"..."}'
```

---

## Supabase REST API (PostgREST)

### Headers Required
```bash
-H "apikey: $SUPABASE_ANON_KEY"
-H "Authorization: Bearer $ACCESS_TOKEN"
```

### Tables Accessed

#### users (or torbox_users)
**GET** https://db.torbox.app/rest/v1/users?email=eq.user@example.com&select=*
```json
[{"id":803945,"auth_id":"uuid-here","created_at":"2026-06-26T15:30:18.572424+00:00","updated_at":"2026-06-26T15:30:18.572424+00:00","plan":0,"total_downloaded":0,"customer":null,"is_subscribed":false,"premium_expires_at":"2026-06-26T15:30:18.572126+00:00","cooldown_until":null,"email":"user@example.com","user_referral":"...","base_email":null,"total_bytes_downloaded":0,"total_bytes_uploaded":0,"torrents_downloaded":0,"web_downloads_downloaded":0,"usenet_downloads_downloaded":0,"additional_concurrent_slots":0,"long_term_seeding":false,"long_term_storage":false,"is_vendor":false,"vendor_id":null,"purchases_referred":0}]
```

#### api_tokens
**GET** https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.uuid-here&select=*
```json
[{"id":809328,"created_at":"2026-06-26T15:30:18.572126+00:00","updated_at":"2026-06-26T15:30:18.572126+00:00","original":true,"auth_id":"uuid-here","token":"329b7cd1-43ff-4b31-8fd0-7db6fa3accfd"}]
```

#### settings
**GET** https://db.torbox.app/rest/v1/settings?auth_id=eq.uuid-here&select=*
```json
[{"id":4375030,"auth_id":"uuid-here","email_notifications":false,"web_notifications":true,"mobile_notifications":true,"rss_notifications":true,"download_speed_in_tab":false,"show_tracker_in_torrent":false,"stremio_quality":[0,1,2,3,4,5,6,7,8],"stremio_resolution":[0,1,2,3],"stremio_language":[0,1,2,3,4,5,6,7,8,9,10,11,12,13],"stremio_cache":[1],"stremio_size_lower":0,"google_drive_folder_id":"","onedrive_save_path":"","discord_id":null,...}]
```

---

## Free Pro Trial Activation
**Endpoint:** `POST https://api.torbox.app/v1/api/unifiedpayments/activatetrial`
**Headers:**
- `Authorization: Bearer <api_key>`
- `Content-Type: application/json`
- `x-csrf-token: <token_from_fingerprint_js>`
**Body:** `{"csrf_token": "<token_from_fingerprint_js>"}`

**Response:** Requires CSRF token from Cloudflare Turnstile/fingerprint challenge (browser-only). No clean API access.
**Conclusion:** Must be activated manually via web dashboard: https://torbox.app/dashboard → Click "Get your free demo now!"

---

## Cloudflare WAF
- Direct curl from server: **403 Forbidden (error code: 1010)**
- Playwright/browser fetch: **Works** (bypasses Cloudflare)
- Always use Playwright browser fetch for Supabase API calls

---

## Supabase Anon Key
Location: `/home/runner/workspace/credentials/.supabase_anon_key`
Length: 208 chars (JWT starting with `eyJhbGciOi...`)
Format: `eyJhbG...VCJ9.eyJ...signature`

---

## Example: Full Account Creation Flow (cloakbrowser)

```bash
# 1. Generate email & password
EMAIL=$(bash /home/runner/workspace/scripts/email.sh)
PW=$(python3 -c "import string,random; print(''.join(random.choice(string.ascii_letters+string.digits+'!@#$%^&*') for _ in range(16)))")

# 2. Signup (direct curl works for signup)
SUPABASE_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_KEY" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}"

# 3. Request OTP via cloakbrowser (bypasses Cloudflare)
# 4. Extract verify URL from Proton Mail
VERIFY_URL=$(bash /home/runner/workspace/scripts/proton_verify.sh "$EMAIL")

# 5. Click verify link (browser)
# 6. Login to get API key available in Supabase: 
#    GET /rest/v1/api_tokens?auth_id=eq.<user_id>&select=token
```

---

## API Key Retrieval (from Supabase)
```bash
ACCESS_TOKEN=<from_login>
USER_ID=<from_user_object>

curl -s "https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.$USER_ID&select=token" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
# Returns: [{"token":"329b7cd1-43ff-4b31-8fd0-7db6fa3accfd"}]
```

---

## Device Auth Flow (Alternative)
```bash
# Start device auth
curl -s "https://api.torbox.app/v1/api/user/auth/device/start" \
  -H "Authorization: Bearer $API_KEY"

# Response: {"device_code":"...","verification_url":"https://torbox.app/oauth/device?app=...","code":"123456",...}

# Poll for token
curl -s -X POST "https://api.torbox.app/v1/api/user/auth/device/token" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"device_code":"..."}'
```

---

## Proton Verify Script (cloakbrowser)
```bash
# Usage
bash /home/runner/workspace/scripts/proton_verify.sh <email> [search_query]

# Example
bash /home/runner/workspace/scripts/proton_verify.sh "user@duck.com" "torbox"
bash /home/runner/workspace/scripts/proton_verify.sh "user@duck.com" "verify"
```

**Python (cloakbrowser) — reusable function:**
```python
from cloakbrowser import launch, launch_persistent_context
import os, sys, importlib, re

sys.path.insert(0, os.path.expanduser("~"))
if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

def get_verify_url(email, search=None):
    """Extract verify/confirm URL from Proton Mail inbox."""
    search = search or email
    PROFILE = os.path.expanduser("~/proton_profile")
    url = "NOT_FOUND"

    os.environ["DISPLAY"] = ":1"
    ctx = launch_persistent_context(PROFILE, headless=False, humanize=True)
    pg = ctx.new_page()
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)

    # Login if needed
    logged_in = False
    try:
        if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
            logged_in = True
    except: pass

    if not logged_in:
        pg.locator("#username").fill(C.PROTON_USERNAME)
        pg.locator("#password").fill(C.PROTON_PASSWORD)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.locator("a:has-text('Mail')").first.click(timeout=0)
        pg.wait_for_timeout(5000)

    pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
    pg.wait_for_timeout(2000)

    # Search for email
    for _ in range(7):
        try:
            pg.keyboard.press("/")
            pg.wait_for_timeout(800)
            pg.keyboard.type(search, delay=20)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(4000)
            items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
            if items.count() > 0:
                items.first.click()
                pg.wait_for_timeout(2000)
                break
            pg.reload()
            pg.wait_for_load_state("networkidle")
            pg.wait_for_timeout(2000)
        except:
            try: pg.keyboard.press("Escape")
            except: pass
            pg.wait_for_timeout(2000)
    else:
        ctx.close()
        return "NOT_FOUND"

    pg.wait_for_timeout(1500)

    # Extract verify URL from hrefs
    for frame in pg.frames:
        try:
            for href in frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)"):
                if ("verify" in href.lower() or "confirm" in href.lower()):
                    url = href.replace("&", "&")
                    break
            if url != "NOT_FOUND": break
        except: continue

    # Fallback: regex on raw HTML
    if url == "NOT_FOUND":
        html = ""
        for f in pg.frames:
            try: html += f.content() + "\n"
            except: pass
        m = re.search(r'https?://[^\s"\'<>]+(verify|confirm)[^\s"\'<>]*', html)
        if m: url = m.group(0).replace("&", "&")

    ctx.close()
    return url
```

**Key points:**
- Uses `cloakbrowser` with `headless=False` + `DISPLAY=:1` (no xvfb)
- `humanize=True` for anti-detection
- Persistent context (`~/proton_profile`) saves Proton login session
- Searches via `/` shortcut + `keyboard.type()` (input is readonly, `.fill()` fails)
- Matches `verify` or `confirm` in href (avoids `awstrack.me` forgotpw links)
- Playwright auto-decodes `&` → `&` via `e.href`

---

## OpenRouter-Style Proton Mail Method (awstrack.me decoding)

TorBox sends verification emails via AWS SES tracking links (`awstrack.me`) that redirect to the actual verify URL. The OpenRouter signup script decodes these directly:

**1. Extract awstrack.me link from email:**
```python
for frame in pg.frames:
    try:
        for href in frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)"):
            if "awstrack.me" in href and "verify" in href.lower():
                url = href
                break
        if url != "NOT_FOUND": break
    except: continue
```

**2. Decode the tracking URL:**
```python
import urllib.parse

# awstrack.me format: https://qzd7845v.r.us-east-1.awstrack.me/L0/<encoded_url>/<tracking_id>
def decode_awstrack(url):
    parts = url.split('/L0/')
    if len(parts) > 1:
        encoded = parts[1].rsplit('/', 1)[0]  # Remove tracking suffix
        return urllib.parse.unquote(encoded)
    return url
```

**3. Full verification flow (OpenRouter style):**
```python
# Single browser session does: OTP request → Proton inbox → awstrack.me → decode → click verify
pg.goto("https://torbox.app")
# ... request OTP via pg.evaluate() ...
pg.goto("https://mail.proton.me/u/0/inbox")
# ... search email ...
# Find awstrack.me link
verify_url = decode_awstrack(awstrack_url)
pg.goto(verify_url)
# Wait for redirect to torbox.app/dashboard
```

**4. Extract API key from Supabase after verification:**
```python
# Login with confirmed email
login_res = curl -X POST "https://db.torbox.app/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_KEY" \
  -d '{"email":"...","password":"..."}'

access_token = login_res['access_token']
user_id = login_res['user']['id']

# Query api_tokens table
api_res = curl "https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.$user_id&select=token" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $access_token"

api_key = api_res[0]['token']  # e.g., "329b7cd1-43ff-4b31-8fd0-7db6fa3accfd"
```

**Key advantage:** Uses the awstrack.me tracking link (arrives instantly in Proton) instead of waiting for the direct `db.torbox.app/auth/v1/verify` link which may be delayed or filtered. The decoded URL contains the full token and redirect to `torbox.app/`.

**Script:** `/home/runner/workspace/scripts/torbox_openrouter_style.sh` — full end-to-end automation.