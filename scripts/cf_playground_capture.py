#!/usr/bin/env python3
"""Capture Cloudflare AI Playground network traffic incl. chat API."""
import json
import time

from cloakbrowser import launch

PLAYGROUND_URL = "https://playground.ai.cloudflare.com/?model=@cf/moonshotai/kimi-k2.7-code"
CAPTURED = {}


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
    browser = launch(headless=False, humanize=True, proxy="socks5://127.0.0.1:40000")
    context = browser.new_context()
    page = context.new_page()

    def log_request(request):
        CAPTURED[request.url] = {
            "method": request.method,
            "headers": dict(request.headers),
            "post_data": request.post_data,
        }

    def log_response(response):
        info = CAPTURED.get(response.url, {})
        info["status"] = response.status
        CAPTURED[response.url] = info

    page.on("request", log_request)
    page.on("response", log_response)

    page.goto(PLAYGROUND_URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(4)
    click_turnstile(page)
    time.sleep(3)

    ta = page.locator("textarea").first
    ta.fill("Say 'Hello from Kimi K2.7 Code' in exactly those words.")
    time.sleep(1)

    # Click the right-side send-like button (last small button in chat bar)
    btns = page.locator("button").all()
    for b in reversed(btns):
        try:
            bb = b.bounding_box()
            if b.is_visible() and bb and bb["x"] > 500:
                b.click()
                break
        except Exception:
            pass

    time.sleep(15)

    print("=== ALL CAPTURED URLS ===")
    for url, info in CAPTURED.items():
        print(f"{info.get('method', 'GET'):<6} {info.get('status', '---'):<4} {url[:120]}")
    print("\n=== INTERESTING POSTS ===")
    for url, info in CAPTURED.items():
        if info.get("method") == "POST" or "ai" in url:
            print(f"\n{info.get('method')} {info.get('status')} {url}")
            print("HEADERS:", json.dumps(info.get("headers", {}), default=str)[:600])
            print("PAYLOAD:", str(info.get("post_data"))[:1000])

    context.close()
    browser.close()


if __name__ == "__main__":
    main()
