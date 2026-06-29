# Proton Mail Inbox Automation

## Pattern

Proton Mail + CloakBrowser for email verification in signup flows.

### Persistent profile approach

```python
from cloakbrowser import launch_persistent_context

ctx = launch_persistent_context("~/proton_profile", headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

# Go directly to inbox (not login page — checks if already logged in)
page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
page.wait_for_timeout(5000)

# Handle login redirect if session expired
if "/login" in page.url:
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(15000)
```

### Search + extract

```python
import re

SIGNUP_EMAIL = "target@duck.com"
for attempt in range(5):
    try:
        page.keyboard.press("/")
        page.wait_for_timeout(1000)
        page.keyboard.type(SIGNUP_EMAIL, delay=80)
        page.keyboard.press("Enter")
        page.wait_for_timeout(5000)
        items = page.locator(".item-container")
        if items.count() > 0:
            items.first.click()
            page.wait_for_timeout(5000)
            break
    except:
        pass
    page.keyboard.press("Escape")
    page.wait_for_timeout(2000)
```

### Extract verification link

```python
verify_url = None
for frame in page.frames:
    try:
        html = frame.content()
        for pat in [
            r'https://service\.firecrawl\.dev/auth/v1/verify[^\s"\'<>,]+',
            r'https://firecrawl\.dev[^\s"\'<>,]*verify[^\s"\'<>,]+',
        ]:
            m = re.findall(pat, html)
            if m:
                verify_url = m[0].replace("&amp;", "&")
                break
        if verify_url:
            break
    except:
        pass

# Fallback: check visible links
if not verify_url:
    for link in page.query_selector_all("a[href]"):
        href = link.get_attribute("href")
        if href and "verify" in href and "firecrawl" in href:
            verify_url = href
            break
```

## Bash integration

In bash+, the `.py` scripts are generated in `~`. The verification pattern:
```bash
VURL=$(python3 ~/fc_proton.py "$PROTON_USER" "$PROTON_PASS" ~/proton_profile "$EMAIL" \
    2>/dev/null | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
```

## Waiting for email

Proton verification emails typically arrive 10–30 seconds after signup.
Use retry loop with 15s sleeps:
```bash
for I in 1 2 3 4 5; do
    sleep 15
    VURL=$(python3 ~/fc_proton.py ...)
    [ "$VURL" != "NOT_FOUND" ] && break
done
```

## Tips

- **Login persistence**: `~/proton_profile` persists Proton session. First run needs full login.
- **Search selector**: `.item-container` is the email list item class
- **Keyboard shortcut**: `/` opens Proton search box
- **Go to inbox directly**: `https://mail.proton.me/u/0/inbox` skips redirect chain
