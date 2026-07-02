#!/usr/bin/env python3
"""Debug helper: launch CloakBrowser on Cloudflare AI Playground and dump page DOM."""
import sys
import time

from cloakbrowser import launch

PLAYGROUND_URL = "https://playground.ai.cloudflare.com/?model=@cf/moonshotai/kimi-k2.7-code"


def click_turnstile(page):
    for f in page.frames:
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb.get("width", 0) > 50:
                    page.mouse.click(fb["x"] + 30, fb["y"] + fb["height"] / 2)
                    return True
            except Exception:
                pass
    return False


def main():
    browser = launch(headless=False, humanize=True)
    context = browser.new_context()
    page = context.new_page()
    page.goto(PLAYGROUND_URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(4)
    click_turnstile(page)
    time.sleep(4)

    print("=== TITLE ===")
    print(page.title())
    print()
    print("=== URL ===")
    print(page.url)
    print()
    print("=== SNAPSHOT ===")
    print(page.content()[:4000])
    print()
    print("=== TEXTAREAS ===")
    print(page.locator("textarea").count())
    for i in range(min(5, page.locator("textarea").count())):
        el = page.locator("textarea").nth(i)
        print(i, el.get_attribute("placeholder"), el.is_visible(), el.bounding_box())
    print()
    print("=== BUTTONS ===")
    for b in page.locator("button").all()[:20]:
        try:
            print(b.text_content()[:60].strip(), b.is_visible(), b.bounding_box())
        except Exception:
            pass

    input("Press Enter to close browser...")
    context.close()
    browser.close()


if __name__ == "__main__":
    main()
