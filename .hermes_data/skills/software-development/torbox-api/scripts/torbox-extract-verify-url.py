#!/usr/bin/env python3
"""
Extract TorBox verify URL from Proton Mail inbox via Playwright.
Usage: python3 scripts/torbox-extract-verify-url.py <email>
Output: the full verify URL (stdout)
"""
import sys, os, re
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

if len(sys.argv) < 2:
    print("Usage: python3 scripts/torbox-extract-verify-url.py <email>", file=sys.stderr)
    sys.exit(1)

email = sys.argv[1]
CH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PR = os.path.expanduser("~/proton_profile")

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        PR, executable_path=CH, headless=True,
        args=["--no-sandbox", "--disable-gpu"]
    )
    pg = ctx.new_page()
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)

    # Detect login state: a logged-in session redirects away from /login to /apps or /mail
    # Do NOT wait for #username — if logged in, it will NOT appear and we'd 30s timeout
    current_url = pg.url
    if "login" not in current_url:
        logged_in = True
    else:
        # Still on login page — need credentials
        logged_in = False
        pg.locator("#username").fill(C.PROTON_USERNAME)
        pg.locator("#password").fill(C.PROTON_PASSWORD)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
        pg.wait_for_timeout(3000)

    if not logged_in:
        # Already navigated to inbox above after credential submission
        pass

    # Go to inbox (idempotent if already there)
    pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
    pg.wait_for_timeout(2000)

    # Search for email by address
    for attempt in range(7):
        try:
            # Clear any existing search input focus before starting new search
            try:
                pg.keyboard.press("Escape")
                pg.wait_for_timeout(500)
            except:
                pass
            pg.keyboard.press("/")
            pg.wait_for_timeout(800)
            pg.keyboard.type(email, delay=20)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(4000)
            items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
            if items.count() > 0:
                # Defocus search input before clicking — the search <input> can intercept
                # pointer events on sibling elements after keyboard.type()
                pg.keyboard.press("Escape")
                pg.wait_for_timeout(500)
                items.first.click(force=True)
                pg.wait_for_timeout(2000)
                break
            pg.reload()
            pg.wait_for_load_state("networkidle")
            pg.wait_for_timeout(2000)
        except:
            try:
                pg.keyboard.press("Escape")
            except:
                pass
            pg.wait_for_timeout(2000)
    else:
        print("NOT_FOUND")
        ctx.close()
        sys.exit(0)

    pg.wait_for_timeout(1500)

    # Extract verify URL from href attributes (Playwright decodes &amp; -> & automatically)
    url = "NOT_FOUND"
    for frame in pg.frames:
        try:
            hrefs = frame.eval_on_selector_all("a[href]", "els => els.map(e => e.href)")
            for href in hrefs:
                if "db.torbox.app/auth/v1/verify" in href:
                    url = href  # already decoded, no &amp; replacement needed
                    break
            if url != "NOT_FOUND":
                break
        except:
            continue

    # Fallback: regex search in raw HTML (must handle &amp;)
    if url == "NOT_FOUND":
        html = ""
        for f in pg.frames:
            try:
                html += f.content() + "\n"
            except:
                pass
        m = re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"<>]*', html)
        if m:
            url = m.group(0).replace("&amp;", "&")

    ctx.close()
    print(url)
