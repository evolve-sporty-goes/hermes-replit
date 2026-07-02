#!/usr/bin/env python3
"""Proxy calls to Cloudflare AI Playground via CloakBrowser (sync)."""
import json
import sys
import time
from typing import Optional

from cloakbrowser import launch
from playwright.sync_api import Response


PLAYGROUND_URL = "https://playground.ai.cloudflare.com/?model=@cf/moonshotai/kimi-k2.7-code"


def _strip_stream_text(text: str) -> list[str]:
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("data:"):
            line = line[len("data:"):].strip()
        if line == "[DONE]":
            break
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        for choice in obj.get("choices", []):
            delta = choice.get("delta", {})
            content = delta.get("content", "")
            if content:
                out.append(content)
    return out


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


def chat(messages: list[dict], timeout: int = 120) -> str:
    response_text: Optional[str] = None

    def _handle(response: Response):
        nonlocal response_text
        if "/ai/run/@cf/moonshotai/kimi-k2.7-code" in response.url:
            try:
                response_text = response.body().decode("utf-8", errors="replace")
            except Exception:
                pass

    browser = launch(headless=False, humanize=True)
    try:
        context = browser.new_context()
        page = context.new_page()
        page.on("response", _handle)

        page.goto(PLAYGROUND_URL, wait_until="domcontentloaded", timeout=60000)

        # Give Turnstile time to render, then click if present.
        time.sleep(2)
        click_turnstile(page)

        page.wait_for_load_state("networkidle", timeout=60000)

        # Locate prompt input.
        input_el = None
        for sel in [
            'textarea[placeholder*="message" i]',
            'textarea[placeholder*="prompt" i]',
            'textarea[placeholder*="ask" i]',
            'textarea',
        ]:
            try:
                el = page.locator(sel).first
                if el.is_visible(timeout=2000):
                    input_el = el
                    break
            except Exception:
                continue

        if not input_el:
            raise RuntimeError("No prompt textarea found on playground page.")

        prompt_text = "\n\n".join(
            f"{m['role'].upper()}: {m['content']}" for m in messages
        )
        input_el.fill(prompt_text)

        # Try to click send, otherwise press Enter.
        send_btn = None
        for sel in [
            'button[type="submit"]',
            'button[aria-label*="send" i]',
            'button:has(svg)',
            'button:has-text("Send")',
        ]:
            try:
                btn = page.locator(sel).first
                if btn.is_visible(timeout=1000):
                    send_btn = btn
                    break
            except Exception:
                continue

        if send_btn:
            send_btn.click()
        else:
            input_el.press("Enter")

        deadline = time.time() + timeout
        while time.time() < deadline:
            if response_text is not None:
                break
            time.sleep(0.5)

        if response_text is None:
            time.sleep(3)
            assistant_nodes = page.locator(
                "[data-message-role='assistant'], .assistant, .message-assistant"
            ).all_text_contents()
            if assistant_nodes:
                return assistant_nodes[-1].strip()
            raise RuntimeError("No API response captured from playground.")

        return "".join(_strip_stream_text(response_text))
    finally:
        try:
            context.close()
        except Exception:
            pass
        browser.close()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        prompt = sys.argv[1]
    else:
        prompt = sys.stdin.read().strip()
    messages = [{"role": "user", "content": prompt}]
    print(chat(messages))
