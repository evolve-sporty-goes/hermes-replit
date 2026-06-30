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
    2>&1 | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
```

**Note**: Use `2>&1` not `2>/dev/null` to preserve debug output. Use `tail -1` not `head -1` and `sed` not `cut` for URL extraction (avoids `pipefail` silent exit on no-match).

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
- **Keyboard shortcut**: `/` opens Proton search box **(but unreliable on u/3/inbox — see Pitfalls)**
- **Go to inbox directly**: `https://mail.proton.me/u/0/inbox` skips redirect chain (but may land on `/u/3/` for some workspaces)

## Pitfalls (2026-07-01 session findings)

| Issue | Symptom | Fix |
|-------|---------|-----|
| `/` shortcut fails | Search box never opens, 0 results found | Click search button explicitly: `page.locator("[data-testid='search-button'], button[aria-label='Search']").first.click()` |
| Workspace path is `/u/3/` not `/u/0/` | Navigation works but search results empty | Accept the redirect; don't hardcode `/u/0/` |
| Search returns 0 results even when email exists | `.item-container` count is 0 | Wait longer (8s), try search button first, add debug logging |
| Email content in encrypted iframe | `page.content()` doesn't show message body | Use `page.locator(".item-container").first.click()` to open message, then scan `page.content()` after 3s wait |
| Proton search requires Enter to execute | Typing query + Enter works but results don't load | `page.wait_for_timeout(6000)` after Enter before checking results |
| `pipefail` kills bash on grep no-match | Script exits silently at Proton step | Remove `pipefail` or use `sed`/`tail` pattern above |

## Robust search pattern (updated 2026-07-01)

```python
for attempt in range(20):
    page.wait_for_timeout(8000)  # wait for email to arrive

    # Try search button first (more reliable than / shortcut)
    try:
        page.locator("[data-testid='search-button'], button[aria-label='Search']").first.click()
    except:
        page.keyboard.press("/")  # fallback
    page.wait_for_timeout(800)
    page.keyboard.type(signup_email, delay=60)
    page.keyboard.press("Enter")
    page.wait_for_timeout(6000)  # critical: wait for results to load

    items = page.locator(".item-container")
    if items.count() == 0:
        page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
        continue

    items.nth(0).click()  # open first result
    page.wait_for_timeout(3000)
    link = find_verify(page)
    if link:
        print(f"VERIFY_URL:{link}", flush=True)
        ctx.close(); sys.exit(0)
    
    # Force-load hidden/quoted content
    page.keyboard.press("a")
    page.wait_for_timeout(2000)
    link = find_verify(page)
    if link:
        print(f"VERIFY_URL:{link}", flush=True)
        ctx.close(); sys.exit(0)

    page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
```
