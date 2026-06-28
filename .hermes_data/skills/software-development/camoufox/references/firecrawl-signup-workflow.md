# Firecrawl Signup + API Key Extraction Workflow

## Overview

Complete workflow to create a Firecrawl account, verify email, and extract the API key using browser automation.

## Prerequisites

- `camoufox` installed (Python)
- System Chromium available at `/nix/store/<hash>-chromium-<version>/bin/chromium`
- `~/config.py` with:
  - `PROTON_USERNAME`, `PROTON_PASSWORD` (for Proton Mail email verification)
  - TorBox credentials (`_CREDENTIAL_POOLS` with `USER` and `API_KEY` for Duck email generation)
- `email.sh` and `duckmail.py` in workspace

## Workflow Steps

### 1. Generate Duck Email

```bash
bash email.sh  # appends new email to mail.txt
# Read last line: tail -1 mail.txt
```

Or in Python:
```python
subprocess.run(["bash", "email.sh"], ...)
with open("mail.txt") as f:
    email = f.read().strip().split("\n")[-1]
```

### 2. Generate Password

Must contain at least one special character (`!@#$%`):
```python
import secrets, string
chars = string.ascii_letters + string.digits + "!@#$%"
pwd = (
    secrets.choice(string.ascii_letters)
    + secrets.choice(string.digits)
    + secrets.choice("!@#%")
    + "".join(secrets.choice(chars) for _ in range(12))
)
# Result: 15 chars with letter + digit + special
```

### 3. Sign Up on Firecrawl (Camoufox)

```python
from camoufox.sync_api import Camoufox

with Camoufox(headless=False) as browser:
    page = browser.new_page()
    page.goto("https://www.firecrawl.dev/signin", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3000)
    
    # Click "Sign Up" tab
    page.click("text=Sign Up")
    page.wait_for_timeout(2000)
    
    # Fill form
    page.locator('input[type="email"]').fill(email)
    page.locator('input[type="password"]').fill(password)
    
    # Submit
    page.get_by_role("button", name="Create Account").click()
    page.wait_for_timeout(10000)
    
    # Success = redirected to /confirm-email
    assert "confirm-email" in page.url
```

### 4. Verify Email (System Chromium → Proton Mail)

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=CHROMIUM_PATH, headless=False)
    page = browser.new_context().new_page()
    
    # Login to Proton (takes 15-30s)
    page.goto("https://account.proton.me/login", timeout=30000)
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    
    # Poll for login completion
    for i in range(20):
        time.sleep(3)
        if "login" not in page.url:
            break
    
    # Click Mail button (don't navigate directly)
    page.locator("a:has-text('Mail')").first.click()
    page.wait_for_timeout(5000)
    
    # Find verification email
    page.locator("text=Confirm Your Signup - Firecrawl").first.click()
    page.wait_for_timeout(5000)
    
    # Extract verification link from frames (encrypted email)
    verify_url = None
    for frame in page.frames:
        html = frame.content()
        if "verify" in html.lower() and "firecrawl" in html.lower():
            matches = re.findall(r'https://service\.firecrawl\.dev/auth/v1/verify[^\s"\'<>]+', html)
            if matches:
                verify_url = matches[0].replace("&amp;", "&")
                break
```

### 5. Visit Verification Link (Camoufox)

```python
with Camoufox(headless=False) as browser:
    page = browser.new_page()
    page.goto(verify_url, timeout=30000)
    page.wait_for_timeout(10000)
    # Success = redirected to /signin
    assert "/signin" in page.url
```

### 6. Sign In + Extract API Key (Camoufox)

The API key is masked on the Settings → API Keys page (`fc-1f985•••••30ab9efb`).
The full key is NOT in the page HTML, and `/api/me` returns the Next.js
frontend HTML (not JSON). The working approach is to **click the eye icon**
to reveal the key, then read the visible text.

```python
with Camoufox(headless=False) as browser:
    page = browser.new_page()
    page.goto("https://www.firecrawl.dev/signin", wait_until="domcontentloaded")
    page.get_by_text("Log In", exact=True).click()
    page.wait_for_timeout(3000)

    page.locator('input[type="email"]').fill(email)
    page.locator('input[type="password"]').fill(password)
    page.get_by_role("button", name="Sign in", exact=True).click()

    # Wait for login (poll, up to 60s)
    for i in range(30):
        time.sleep(2)
        if "/signin" not in page.url:
            break

    # Navigate to API Keys page
    page.goto("https://www.firecrawl.dev/app/api-keys", timeout=30000)
    page.wait_for_timeout(5000)

    # PRIMARY: Click eye icon to reveal the masked key
    api_key = None
    page.click("button:has(.lucide-eye)")
    page.wait_for_timeout(3000)
    api_key = page.locator("text=fc-").first.text_content().strip()
    assert api_key.startswith("fc-"), f"Doesn't look like a key: {api_key}"

    # FALLBACK 1: eye-off variant
    if not api_key:
        page.click("button:has(.lucide-eye-off)")
        page.wait_for_timeout(3000)
        api_key = page.locator("text=fc-").first.text_content().strip()

    # FALLBACK 2: Copy button + clipboard
    if not api_key:
        page.click('[aria-label="Copy"]')
        page.wait_for_timeout(1500)
        clipboard = page.evaluate("navigator.clipboard.readText()")
        if clipboard and clipboard.startswith("fc-"):
            api_key = clipboard.strip()

    # FALLBACK 3: Regex against HTML
    if not api_key:
        html = page.content()
        matches = re.findall(r'fc-[a-zA-Z0-9]{20,}', html)
        if matches:
            api_key = max(matches, key=len)
```

### 7. Save Credentials

```python
with open("firecrawl_credentials.txt", "w") as f:
    f.write(f"EMAIL={email}\n")
    f.write(f"PASSWORD={password}\n")
    f.write(f"API_KEY={api_key}\n")
```

## Key Gotchas

| Issue | Solution |
|-------|----------|
| Password rejected | Include at least one of `!@#$%` |
| Sign in button not found | Use `name="Sign in"` (lowercase 'in') with `exact=True` |
| Login stuck on "Loading..." | Poll URL for up to 60s, don't rely on short timeouts |
| API key masked in UI | **Primary:** Navigate to `/app/api-keys`, click `button:has(.lucide-eye)` to reveal, then read `page.locator("text=fc-").first.text_content()`. **Fallbacks:** eye-off button, `[aria-label="Copy"]` + clipboard, regex `fc-[a-zA-Z0-9]{20,}` on HTML. Note: `/api/me` is a Next.js frontend route — it returns HTML, NOT JSON. |
| Camoufox crashes on Proton | Use system Chromium for Proton Mail access |
| `wait_for_url("**/path")` times out | Poll `page.url` in a loop instead |
| Email body empty in Proton | Content is encrypted; use `frame.content()` HTML extraction |
| Verification link contains `&amp;` | HTML-escaped `&` breaks redirects. Apply `.replace("&amp;", "&")` before `page.goto()` |
| `/api/me` returns HTML not JSON | This is a Next.js frontend route. Don't use it. Use eye icon reveal instead. |

## Consolidated Script

The actual implementation (`fcapi.py`) uses this flow:
- `step5_signin_and_get_apikey(verify_url, email, password)` — visits verify_url first, then logs in
- `step7_save(email, password, api_key)` — appends to `firecrawl_credentials.txt` (mode `"a"`)

See `templates/firecrawl-signup-complete.py` for a single-file implementation of this entire workflow.
