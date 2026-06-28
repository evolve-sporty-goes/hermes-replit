# Magic Link Browser Flow — Trial Activation

Session-tested flow for activating the 24-hour free Pro trial via magic link + browser.

## Prerequisites

- `FIRECRAWL_API_KEY` set (for `firecrawl scrape` to get a browser session)
- `SUPABASE_ANON_KEY` from `/home/runner/workspace/.hermes_data/.env`
- TorBox account credentials in `torbox_credentials.txt`

## Step-by-step

### 1. Request magic link (script file required)

```bash
cat > /tmp/torbox_otp.sh << 'SCRIPT'
#!/bin/bash
ANON_KEY=$(grep SUPABASE_ANON_KEY /home/runner/workspace/.hermes_data/.env | cut -d= -f2 | tr -d '\n\r')
curl -s -X POST 'https://db.torbox.app/auth/v1/otp' \
  -H "apikey: *** \
  -H "Authorization: Bearer *** \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\"}"
SCRIPT
bash /tmp/torbox_otp.sh user@example.com
```

### 2. Check email for tracking URL

Email arrives with a URL like:
`https://qzd7845v.r.us-east-1.awstrack.me/L0/https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app/...`

### 3. Navigate to tracking URL in browser

```
browser_navigate(url='<full tracking URL from email>')
```

The browser follows the redirect chain automatically:
- AWS tracker → Supabase verify → torbox.app/#access_token=...

**WARNING: This consumes the single-use token.** If the page fails to load, request a new magic link.

### 4. Verify session landed on dashboard

```javascript
// browser_console
window.location.href
// Should be: https://torbox.app/#access_token=...
```

### 5. Check plan status

```javascript
// browser_console
const auth = JSON.parse(localStorage.getItem('sb-db-auth-token'));
const r = await fetch('https://api.torbox.app/v1/api/user/me', {headers: {'Authorization': 'Bearer ' + auth.access_token}});
const d = await r.json();
d.data.plan;  // 0 = free, 1 = pro (trial or paid)
```

### 6. Click "Get your free demo now!" button

Use browser_snapshot to find the button ref, then browser_click. The button triggers:
1. CsrfGuard PoW challenge (automatic JS)
2. activatetrial POST
3. Plan changes from 0 to 1

### 7. Extract API key from Settings

After trial activation, navigate to `https://torbox.app/settings` and extract the API key from the page. Or query via Supabase:

```bash
# Using the access_token from step 3
curl -s "https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.<user_uuid>&select=token" \
  -H "apikey: <supabase_anon_key>" \
  -H "Authorization: Bearer <access_token>"
```

## Common failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `about:blank` after navigate | Tracking redirect failed / network error | Request fresh magic link |
| `otp_expired` in URL | Token already consumed (single-use) | Request fresh magic link |
| `Invalid API key` on OTP request | Using stale `.supabase_anon_key` file | Use `.env` copy instead |
| Dashboard shows "Login" | Session lost during navigation | Request fresh magic link, navigate once |
| Button click does nothing visible | CsrfGuard XHR is async | Check `/user/me` via console fetch |
| Trial still shows plan=0 after click | **Disposable email domain rejected** | Server returns 403 PAYMENT_ERROR at activatetrial step 4. Use non-disposable email (Gmail/Outlook) |
| `PLAN_RESTRICTED_FEATURE` on API calls | Trial not activated or free plan | Activate trial via dashboard button (requires non-disposable email) |
| Login form `#username` 30s timeout | Logged-in profile redirected to `/apps` — form never loads | Check `pg.url` after `goto("/login")`: if `"login"` not in URL, skip credential entry |
| `items.first.click()` hangs on email result | Search `<input>` retains focus and intercepts pointer events | Press `Escape` + `click(force=True)` after search |
| Verify URL found but `NOT_FOUND` printed | Extraction checked main frame only, URL is in email-body iframe | Already handled by multi-frame loop — verify frame count if regenerating |
| `magiclink.sh` returns `NOT_FOUND` even though email arrived | Workspace `.sh` script has unpatched click bug (no `Escape`/`force=True`) | Run `torbox-extract-verify-url.py` directly — it has the fixes |
| User wants link-only without login | Agent incorrectly navigates to the URL, consuming it | Use generate-only mode: output URL to stdout, do NOT `browser_navigate` |
