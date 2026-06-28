# Generate-Only Magic Link Mode

## When to use

User says any of:
- "Generate the link, don't click"
- "Just give me the URL"
- "I'll click it myself"
- "It expires if you click it"

## Flow

1. Request OTP (Playwright browser fetch or curl)
2. Extract verify URL from Proton Mail via Playwright
3. Output the URL to stdout — **do NOT `browser_navigate` to it**

## Output format

Return both forms:
- **Full email link** (may include `*.awstrack.me/L0/...` wrapper) — this is what the user sees in their inbox
- **Direct Supabase URL** (decoded) — shorter, usable in curl or headless browser

Example:
```
Full: https://qzd7845v.r.us-east-1.awstrack.me/L0/https:%2F%2Fdb.torbox.app%2Fauth%2Fv1%2Fverify%3Ftoken=abc123%26type=magiclink%26redirect_to=https:%2F%2Ftorbox.app%2F...
Direct: https://db.torbox.app/auth/v1/verify?token=abc123&type=magiclink&redirect_to=https://torbox.app/
```

## Decoding the tracker URL

When the extracted link contains `/L0/` (AWS SES tracking wrapper), decode the inner URL:
```python
import urllib.parse
if "/L0/" in tracker_url:
    encoded = tracker_url.split("/L0/")[1]
    decoded = urllib.parse.unquote(urllib.parse.unquote(encoded))
    # decoded = "https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=https://torbox.app/"
```
The double `unquote` handles double-encoded paths (`%252F` → `%2F` → `/`).

## Fallback when `magiclink.sh` returns NOT_FOUND

The workspace `scripts/magiclink.sh` has a known bug: `items.first.click()` fails when the Proton search `<input>` retains focus and intercepts pointer events. If the user says "run magiclink" and the script returns `NOT_FOUND`, do NOT tell the user "no email found" — instead, run the robust Python extraction directly:

```bash
# Request OTP (Playwright bypasses Cloudflare)
python3 scripts/torbox-request-otp.py <email>

# Extract verify URL (has Escape + force=True fixes)
python3 scripts/torbox-extract-verify-url.py <email>
```

The Python script (`scripts/torbox-extract-verify-url.py`) handles:
- Proton login detection via URL (not form elements — avoids 30s timeout)
- `Escape` defocus before clicking email items
- `force=True` to bypass actionability check
- Multi-frame href extraction (verify URL is in email-body iframe)
- Regex fallback with `&amp;` → `&` replacement
