#!/usr/bin/env python3
"""Proxy calls to Cloudflare AI Playground via CloakBrowser."""
import json
import re
import sys
import time
from dataclasses import dataclass
from typing import Iterator

from cloakbrowser import launch
from playwright.sync_api import sync_playwright, Request, Response


PLAYGROUND_URL = "https://playground.ai.cloudflare.com/?model=@cf/moonshotai/kimi-k2.7-code"


def _strip_stream_json(text: str) -> list[str]:
    """Parse Cloudflare Workers AI streaming NDJSON."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        # Drop 'data: ' prefix if present
        if line.startswith("data:"):
            line = line[len("data:"):].strip()
        if line == "[DONE]":
            break
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        # OpenAI-compatible delta
        for choice in obj.get("choices", []):
            delta = choice.get("delta", {})
            content = delta.get("content", "")
            if content:
                out.append(content)
    return out


def chat(messages: list[dict], timeout: int = 120) -> str:
    """Send messages to the playground and return the assistant reply."""
    response_text = None

    def _handle(response: Response):
        nonlocal response_text
        url = response.url
        if "/ai/run/@cf/moonshotai/kimi-k2.7-code" in url:
            try:
                response_text = response.body().decode("utf-8", errors="replace")
            except Exception:
                pass

    with sync_playwright() as p:
        browser = launch(headless=False, humanize=True)
        try:
            context = browser.new_context()
            page = context.new_page()
            page.on("response", _handle)

            # Load playground; model is pre-selected via query param.
            page.goto(PLAYGROUND_URL, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_load_state("networkidle", timeout=60000)

            # Find prompt input.
            placeholder_selectors = [
                'textarea[placeholder*="message" i]',
                'textarea[placeholder*="prompt" i]',
                'textarea[placeholder*="ask" i]',
                'textarea',
            ]
            input_el = None
            for sel in placeholder_selectors:
                try:
                    input_el = page.locator(sel).first
                    if input_el.is_visible(timeout=2000):
                        break
                except Exception:
                    continue
            if not input_el:
                raise RuntimeError("Could not find prompt textarea on playground page.")

            # Combine messages into a single user prompt (playground is chat-like single-turn).
            prompt_text = "\n\n".join(
                f"{m['role'].upper()}: {m['content']}" for m in messages
            )

            input_el.fill(prompt_text)
            # Try clicking the send arrow / button.
            send_btn = None
            for selector in [
                'button[type="submit"]',
                'button[aria-label*="send" i]',
                'button:has(svg)',
                'button:has-text("→")',
                'button:has-text("Send")',
            ]:
                try:
                    btn = page.locator(selector).first
                    if btn.is_visible(timeout=1000):
                        send_btn = btn
                        break
                except Exception:
                    continue

            if send_btn:
                send_btn.click()
            else:
                input_el.press("Enter")

            # Wait for streaming response to finish.
            deadline = time.time() + timeout
            while time.time() < deadline:
                if response_text is not None:
                    break
                time.sleep(0.5)

            if response_text is None:
                # Wait a bit longer for the UI to render.
                time.sleep(3)
                # Try scraping assistant message from DOM.
                assistant_nodes = page.locator("[data-message-role='assistant'], .assistant, .message-assistant").all_text_contents()
                if assistant_nodes:
                    return assistant_nodes[-1].strip()
                raise RuntimeError("No API response captured from playground.")

            return "".join(_strip_stream_json(response_text))
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
