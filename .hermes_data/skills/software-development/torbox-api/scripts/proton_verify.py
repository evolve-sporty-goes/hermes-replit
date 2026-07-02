#!/usr/bin/env python3
"""
proton_verify.py — Extract verify/confirm URL from Proton Mail inbox using cloakbrowser.

Usage:
    python proton_verify.py <email> [search_query]

    email: email to search for in Proton inbox
    search_query: optional additional search term (default: same as email)

Returns:
    verify URL on stdout, or "NOT_FOUND"
"""

from cloakbrowser import launch, launch_persistent_context
import os, sys, importlib, re

sys.path.insert(0, os.path.expanduser("~"))
if "config" in sys.modules:
    del sys.modules["config"]
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
    except:
        pass

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
            try:
                pg.keyboard.press("Escape")
            except:
                pass
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
            if url != "NOT_FOUND":
                break
        except:
            continue

    # Fallback: regex on raw HTML
    if url == "NOT_FOUND":
        html = ""
        for f in pg.frames:
            try:
                html += f.content() + "\n"
            except:
                pass
        m = re.search(r'https?://[^\s"\'<>]+(verify|confirm)[^\s"\'<>]*', html)
        if m:
            url = m.group(0).replace("&", "&")

    ctx.close()
    return url


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python proton_verify.py <email> [search_query]", file=sys.stderr)
        sys.exit(1)

    email = sys.argv[1]
    search = sys.argv[2] if len(sys.argv) > 2 else None
    url = get_verify_url(email, search)
    print(url, end="")