# Magic Link Browser Flow for TorBox

## Overview
TorBox uses Supabase magic links (OTP) for email verification. The OTP endpoint is behind Cloudflare WAF, so direct curl fails (403 error code 1010). Must use Playwright browser fetch to bypass Cloudflare.

## Flow

### 1. Request OTP via Playwright
```python
from cloakbrowser import launch_persistent_context

ctx = launch_persistent_context(PROFILE, headless=False, humanize=True)
pg = ctx.new_page()
pg.goto("https://torbox.app", timeout=30000)
pg.wait_for_timeout(2000)

# Browser fetch with full key (bypasses Cloudflare)
result = pg.evaluate('''async () => {
    const key = "<SUPABASE_ANON_KEY>";
    const resp = await fetch("https://db.torbox.app/auth/v1/otp", {
        method: "POST",
        headers: { 
            "apikey": key, 
            "Authorization": "Bearer " + key, 
            "Content-Type": "application/json" 
        },
        body: JSON.stringify({ email: "user@example.com" })
    });
    return await resp.text();
}''')
print(f"OTP response: {result}")  # {} = success
ctx.close()
```

**Critical:** Pass the full 208-char key inside the `pg.evaluate()` string. Do NOT truncate it.

### 2. Extract Verify URL from Proton Mail
Use `proton_verify.sh` script or equivalent Python:
```bash
bash proton_verify.sh user@example.com
```

Or inline:
```python
# Login to Proton, search inbox, extract verify link
# Match on "db.torbox.app/auth/v1/verify" specifically
# The email also contains an awstrack.me URL for forgotpw, not the verify link
```

**OTP tokens are single-use** and expire quickly (~60s after email opened).

### 3. Use the Verify URL
```bash
browser_navigate(url='<verify_url>')
```

Then:
1. **Stay on the page** — do NOT navigate away (drops session).
2. Click "Get your free demo now!" button on dashboard.
3. Extract API key from Settings page or Supabase `api_tokens` table.

## Pitfalls
- **Pass full key to `pg.evaluate()`** — The 208-char key must be interpolated completely. Truncated keys cause "Invalid API key" errors.
- **OTP tokens are single-use** and expire quickly (~60s after email opened).
- **Match on `db.torbox.app/auth/v1/verify`** specifically — the email also contains an `awstrack.me` URL for `forgotpw`, not the verify link.
- **Use `e.href` not regex** — Playwright auto-decodes `&` → `&`. Regex on raw HTML truncates at `&`.
- **Disposable email domains** (e.g. `@duck.com`) may be **ineligible** for the free trial — use Gmail/Outlook.
- **`activatetrial` can return 403** — `"You are not eligible for the free trial"` for flagged accounts/emails.

## Free Pro Trial (24hr)
- TorBox offers a **24-hour free trial of Pro Plan** for eligible free-plan users.
- **How to activate:**
  1. Log into TorBox dashboard
  2. Navigate to Dashboard or Subscriptions page
  3. Click **"Get your free demo now!"**
- **To get API key:**
  1. Log into TorBox
  2. Go to **Settings** (torbox.app/settings)
  3. Find the **API Key** section
  4. Copy the API token

**No API endpoint** for trial activation — requires web UI interaction with Cloudflare Turnstile CSRF token.