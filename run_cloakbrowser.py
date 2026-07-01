#!/usr/bin/env python3
import asyncio
import os
from playwright.async_api import async_playwright

async def main():
    os.environ["DISPLAY"] = ":100"
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path="/home/runner/.cloakbrowser/chromium-146.0.7680.177.5/chrome",
            headless=False,
            proxy={"server": "socks5://127.0.0.1:40000"},
            args=[
                "--disable-blink-features=AutomationControlled",
                "--proxy-server=socks5://127.0.0.1:40000",
                "--host-resolver-rules=MAP * ~NOTFOUND , EXCLUDE 127.0.0.1",
            ]
        )
        page = await browser.new_page()
        await page.goto("https://torbox.app")
        print("Opened torbox.app via CloakBrowser + ProtonVPN SOCKS5 proxy on DISPLAY=:100")
        print("Press Ctrl+C to close...")
        await asyncio.Event().wait()

if __name__ == "__main__":
    asyncio.run(main())