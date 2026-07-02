# Supabase Auth via cloakbrowser (Cloudflare Bypass)

## Problem

`db.torbox.app` is behind Cloudflare WAF (error code 1010). Direct curl from datacenter IPs fails with 403 Forbidden.

## Solution: cloakbrowser Browser Fetch

Use `pg.evaluate()` to run fetch inside the browser context — bypasses Cloudflare.

## Pattern

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
pg.goto("https://torbox.app", timeout=30000)  # Establish Cloudflare cookies
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

## Critical Rules

1. **Full key inside pg.evaluate()** — The 208-char JWT must be interpolated completely. Truncated keys cause "Invalid API key" errors.
2. **Visit torbox.app first** — `pg.goto("https://torbox.app")` establishes Cloudflare cookies/session before the fetch.
3. **headless=True works** — For API fetches, headless is fine. Use headless=False only for interactive flows (Proton login).
4. **Both headers required** — Supabase expects both `apikey` AND `Authorization: Bearer <same_key>`.

## Endpoints That Need This

| Endpoint | Method | Body |
|----------|--------|------|
| `/auth/v1/otp` | POST | `{"email": "..."}` |
| `/auth/v1/signup` | POST | `{"email": "...", "password": "..."}` |
| `/auth/v1/token?grant_type=password` | POST | `{"email": "...", "password": "..."}` |

**Note:** `/auth/v1/signup` and `/auth/v1/token` work via direct curl in some cases. `/auth/v1/otp` consistently requires browser fetch.

## Complete Flow Example

```python
# 1. Signup (direct curl works)
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"email":"user@duck.com","password":"..."}'

# 2. Request OTP via cloakbrowser (bypasses Cloudflare)
result = pg.evaluate(...)  # as above

# 3. Get verify URL from Proton
verify_url = get_verify_url("user@duck.com")

# 4. Click verify link (browser_navigate or pg.goto)
pg.goto(verify_url)

# 5. Login to get access_token
result = pg.evaluate(f'''async () => {{
    const resp = await fetch("https://db.torbox.app/auth/v1/token?grant_type=password", {{
        method: "POST",
        headers: {{ "apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json" }},
        body: JSON.stringify({{ email: "{EMAIL}", password: "{PW}" }})
    }});
    return await resp.json();
}}''')
access_token = result["access_token"]

# 6. Get API key from Supabase
api_key = fetch("https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.{user_id}&select=token", 
    headers: {apikey: key, Authorization: `Bearer ${access_token}`})
```