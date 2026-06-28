# Proton Mail Session Debugging (Session 2026-06-27)

## Problem: Login detection false-negative

**Symptom:** `pg.locator("a:has-text('Mail')").is_visible(timeout=3000)` raises `TimeoutError` even when the Proton profile is logged in.

**Root cause:** When a logged-in persistent profile navigates to `account.proton.me/login`, Proton redirects immediately to `account.proton.me/apps` (or `mail.proton.me/...`). The `#username` and `a:has-text('Mail')` selectors do not exist on the redirected page — they only exist on the login form.

**Fix:** Check `pg.url` after `goto("https://account.proton.me/login")`:
```python
pg.goto("https://account.proton.me/login", timeout=60000)
pg.wait_for_timeout(3000)
if "login" not in pg.url:
    logged_in = True  # redirected away = authenticated
```

## Problem: Email item click intercepted by search input

**Symptom:** After `keyboard.type(email)` + `Enter` in search, `items.first.click()` fails with: `<input ... id="to-composer-702" .../> from <div>…</div> subtree intercepts pointer events`. Playwright retries indefinitely.

**Root cause:** The Proton search `<input>` retains keyboard focus after `keyboard.type()`. Subsequent clicks on sibling DOM elements get routed to the input instead.

**Fix sequence:**
```python
pg.keyboard.press("Escape")   # defocus the search input
pg.wait_for_timeout(500)      # let focus clear
items.first.click(force=True)  # force=True bypasses actionability wait
```

If `force=True` still fails, nuclear option:
```python
pg.evaluate('''() => {
  const el = document.querySelector('.item-container, .message-item, [data-testid="message-item"]');
  el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
}''')
```

## Problem: Extracted link returns NO_LINK_FOUND despite emails existing

**Symptom:** `items.count()` returns 5-8 emails, but `NO_LINK_FOUND` is printed — no verify URL extracted from any frame.

**Root cause:** The verify URL may be in a frame that Playwright's `eval_on_selector_all("a[href]")` cannot reach (e.g. `about:blank` frame with cross-origin content), or the URL is split across HTML entities that break href extraction.

**Fix:** Always run the regex fallback even when frame extraction succeeds partially:
```python
# Fallback: regex search in raw HTML (must handle &amp;)
if url == "NOT_FOUND":
    html = ""
    for f in pg.frames:
        try:
            html += f.content() + "\n"
        except:
            pass
    # Match awstrack tracker URLs containing verify
    m = re.search(r'https://qzd7845v\.r\.us-east-1\.awstrack\.me/L0/[^\s"<>]*verify[^\s"<>]*', html)
    if m:
        url = m.group(0)
    else:
        # Match direct Supabase URLs
        m2 = re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"<>]*', html)
        if m2:
            url = m2.group(0).replace("&amp;", "&")
```

**Verified 2026-06-27:** The verify URL was found in Frame 3 (`about:blank`) while Frame 0 (inbox list) had no matching hrefs. The regex fallback on `f.content()` successfully captured the truncated URL from the email body.

## Problem: Verify URL in unexpected frame

**Symptom:** `for frame in pg.frames: frame.eval_on_selector_all("a[href]", ...)` finds no match in frame 0 (the inbox list), only in frame 3 or later.

**Root cause:** Proton Mail renders email content in a dedicated iframe. The verify URL exists inside the email body iframe, not the main navigation frame. The extraction code must iterate ALL frames — this was already correct in the script but the frame index varies.

**Note:** The `data-testid` attribute on the list item contains the subject: `data-testid="message-item:Confirm Your Signup with TorBox"`. Use `starts-with` matching if you want to filter by sender/subject without opening the email.

## Operator feedback style

The agent ran the pre-existing `magiclink.sh` script, found it returned `NOT_FOUND`, and had to diagnose and fix the issues interactively. The fixes are now encoded in `scripts/torbox-extract-verify-url.py` and the pitfall list above so future runs of "run magiclink <email>" succeed without manual intervention.
