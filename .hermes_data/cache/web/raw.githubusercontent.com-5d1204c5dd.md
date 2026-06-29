import asyncio
import logging
import os
from collections import namedtuple
from typing import Optional, Dict, Any
from urllib.parse import urlparse

\# Skip the per-launch PyPI version check (latency/offline-unfriendly in prod/CI)
os.environ.setdefault("CLOAKBROWSER\_AUTO\_UPDATE", "false")

import cloakbrowser as cb

from cf\_bypasser.utils.misc import cache\_key, get\_browser\_init\_lock, per\_loop
from cf\_bypasser.utils.constants import (
 DEFAULT\_TIMEOUT\_MS,
 CHALLENGE\_SETTLE\_SECONDS,
 HTML\_SETTLE\_POLL\_SECONDS,
 HTML\_SETTLE\_STABLE\_ROUNDS,
 HTML\_SETTLE\_MAX\_SECONDS,
 RETRY\_POLL\_SECONDS,
 CONTEXT\_CLOSE\_TIMEOUT\_SECONDS,
 DEFAULT\_MAX\_RETRIES,
 DEFAULT\_CACHE\_FILE,
 MAX\_CONCURRENT\_BROWSERS,
 IP\_CHECK\_ENABLED,
)
from cf\_bypasser.utils.ipcheck import get\_exit\_ip
from cf\_bypasser.cache.cookie\_cache import CookieCache

\_MAX\_CONCURRENT\_BROWSERS = MAX\_CONCURRENT\_BROWSERS

\# One semaphore + one in-flight lock registry per event loop (multi-loop pytest safe).
\_browser\_semaphores: dict = {}
\_inflight\_locks: dict = {}

ChallengeResult = namedtuple("ChallengeResult", ("success", "cf\_detected", "status"))

def \_browser\_semaphore() -> asyncio.Semaphore:
 # read \_MAX\_CONCURRENT\_BROWSERS at creation time so monkeypatching it takes effect
 return per\_loop(\_browser\_semaphores, lambda: asyncio.Semaphore(\_MAX\_CONCURRENT\_BROWSERS))

def \_inflight\_lock(key: str) -> asyncio.Lock:
 registry = per\_loop(\_inflight\_locks, dict)
 lock = registry.get(key)
 if lock is None:
 lock = asyncio.Lock()
 registry\[key\] = lock
 return lock

\# Native closed-shadow-root access via the patched Chromium — lets us read and
\# click the Cloudflare Turnstile checkbox without injecting attachShadow patches.
FAKE\_SHADOW\_ARG = "--enable-blink-features=FakeShadowRoot"

\# JS run inside the Turnstile iframe: walk open + closed shadow roots and return
\# the checkbox centre relative to the iframe viewport.
\_FIND\_CHECKBOX\_JS = """() => {
 function find(root){
 if(!root) return null;
 const direct = root.querySelector && root.querySelector('input\[type=checkbox\]');
 if(direct) return direct;
 for(const el of (root.querySelectorAll ? root.querySelectorAll('\*') : \[\])){
 const sr = el.fakeShadowRoot \|\| el.shadowRoot;
 if(sr){ const r = find(sr); if(r) return r; }
 }
 return null;
 }
 const cb = find(document);
 if(!cb) return {found:false};
 const r = cb.getBoundingClientRect();
 return {found:true, checked:cb.checked, x:r.x+r.width/2, y:r.y+r.height/2, w:r.width};
}"""

class CloakBypasser:
 """Cloudflare bypasser backed by CloakBrowser (stealth Chromium) with cookie caching."""

 def \_\_init\_\_(self, max\_retries: int = DEFAULT\_MAX\_RETRIES, log: bool = True, cache\_file: str = DEFAULT\_CACHE\_FILE):
 self.max\_retries = max\_retries
 self.log = log
 self.cookie\_cache = CookieCache(cache\_file)

 def log\_message(self, message: str) -> None:
 if self.log:
 logging.info(message)

 def parse\_proxy(self, proxy: str) -> Optional\[Dict\[str, str\]\]:
 """Parse a proxy URL into a Playwright/CloakBrowser proxy dict."""
 try:
 parsed = urlparse(proxy)
 if not parsed.hostname or not parsed.port:
 self.log\_message(f"Invalid proxy format: {proxy}")
 return None

 proxy\_config = {"server": f"{parsed.scheme}://{parsed.hostname}:{parsed.port}"}
 if parsed.username and parsed.password:
 proxy\_config\["username"\] = parsed.username
 proxy\_config\["password"\] = parsed.password
 return proxy\_config
 except Exception as e:
 self.log\_message(f"Error parsing proxy {proxy}: {e}")
 return None

 async def setup\_browser(self, proxy: Optional\[str\] = None, lang: str = "en", user\_agent: Optional\[str\] = None, headless: bool = False) -> tuple:
 """Launch a fresh, profile-less CloakBrowser context. Returns (context, page)."""
 self.cookie\_cache.clear\_expired()

 proxy\_config = None
 if proxy:
 proxy\_config = self.parse\_proxy(proxy)
 if proxy\_config:
 self.log\_message(f"Using proxy: {proxy\_config\['server'\]}")
 else:
 # never silently fall back to direct: that leaks the real IP
 raise ValueError(f"Invalid proxy, refusing to continue direct: {proxy}")

 launch\_kwargs = dict(
 headless=headless,
 args=\[FAKE\_SHADOW\_ARG\],
 geoip=bool(proxy\_config),
 locale=lang if lang else None,
 )
 if proxy\_config:
 launch\_kwargs\["proxy"\] = proxy\_config
 if user\_agent:
 launch\_kwargs\["user\_agent"\] = user\_agent

 context = None
 try:
 # browserforge fingerprint generation isn't thread-safe; serialize launches
 async with get\_browser\_init\_lock():
 context = await cb.launch\_context\_async(\*\*launch\_kwargs)
 page = context.pages\[0\] if context.pages else await context.new\_page()
 page.set\_default\_timeout(DEFAULT\_TIMEOUT\_MS)
 page.set\_default\_navigation\_timeout(DEFAULT\_TIMEOUT\_MS)
 return context, page
 except BaseException:
 # a partial launch must never orphan a browser process,
 # even on cancellation/timeout (hence BaseException)
 await self.cleanup\_browser(context)
 raise

 # block-specific phrases; "cloudflare ray id" alone is NOT enough (legit footers have it)
 \_BLOCK\_MARKERS = (
 "you have been blocked",
 "sorry, you have been blocked",
 "error 1020",
 "access denied",
 )

 async def is\_bypassed(self, page) -> bool:
 """Check if the Cloudflare challenge has been cleared (and not a block page)."""
 try:
 title = await page.title()
 if "just a moment" in title.lower():
 return False
 html\_content = await page.content()
 lowered = html\_content.lower()
 if "please complete the captcha" in lowered:
 return False
 if any(marker in lowered for marker in self.\_BLOCK\_MARKERS):
 return False
 return True
 except Exception as e:
 self.log\_message(f"Error checking bypass status: {e}")
 return False

 async def \_click\_turnstile\_checkbox(self, page) -> bool:
 """Find the Turnstile checkbox via fakeShadowRoot and click it. Returns True if clicked."""
 cf\_frames = \[f for f in page.frames if "challenges.cloudflare" in (f.url or "")\]
 for frame in cf\_frames:
 try:
 info = await frame.evaluate(\_FIND\_CHECKBOX\_JS)
 if not info.get("found") or info.get("w", 0) <= 0 or info.get("checked"):
 continue
 frame\_el = await frame.frame\_element()
 box = await frame\_el.bounding\_box()
 if not box:
 continue
 # checkbox coords are iframe-relative; offset by the iframe's page position
 await page.mouse.click(box\["x"\] + info\["x"\], box\["y"\] + info\["y"\])
 # only count it as clicked if the box became checked or disappeared
 after = await frame.evaluate(\_FIND\_CHECKBOX\_JS)
 if (not after.get("found")) or after.get("checked"):
 self.log\_message("Clicked Turnstile checkbox via fakeShadowRoot")
 return True
 self.log\_message("Turnstile checkbox click did not register, retrying")
 except Exception as e:
 self.log\_message(f"Checkbox click attempt failed: {e}")
 return False

 async def solve\_cloudflare\_challenge(self, url: str, page) -> tuple:
 """Navigate to URL and clear any Cloudflare challenge. Returns (success, cf\_detected, status)."""
 cf\_detected = False
 status = 200
 try:
 self.log\_message(f"Navigating to {url}")
 try:
 response = await page.goto(url, wait\_until="domcontentloaded", timeout=DEFAULT\_TIMEOUT\_MS)
 if response is not None and getattr(response, "status", None):
 status = response.status
 except Exception as nav\_err:
 self.log\_message(f"Navigation warning: {nav\_err}")

 # let the challenge scripts load before deciding it's unprotected
 await asyncio.sleep(CHALLENGE\_SETTLE\_SECONDS)
 try:
 html\_content = await page.content()
 content\_ok = True
 except Exception:
 html\_content = ""
 content\_ok = False

 if not content\_ok:
 # a failed read tells us nothing; never claim success on empty content
 self.log\_message("Could not read page content -- treating as unconfirmed")
 bypassed = await self.is\_bypassed(page)
 return ChallengeResult(bypassed, cf\_detected, status)

 if "cloudflare" not in html\_content.lower():
 self.log\_message("No Cloudflare protection detected -- either not protected or already bypassed")
 return ChallengeResult(True, cf\_detected, status)

 cf\_detected = True
 if await self.is\_bypassed(page):
 self.log\_message("No Cloudflare challenge detected or already bypassed")
 return ChallengeResult(True, cf\_detected, status)

 self.log\_message("Cloudflare challenge detected. Waiting for resolution...")
 clicked = False
 for \_ in range(self.max\_retries):
 if await self.is\_bypassed(page):
 self.log\_message("Cloudflare challenge solved successfully!")
 return ChallengeResult(True, cf\_detected, status)
 # non-interactive challenges auto-resolve; interactive ones need one click
 if not clicked:
 clicked = await self.\_click\_turnstile\_checkbox(page)
 await asyncio.sleep(RETRY\_POLL\_SECONDS)

 if await self.is\_bypassed(page):
 self.log\_message("Cloudflare challenge solved successfully!")
 return ChallengeResult(True, cf\_detected, status)

 self.log\_message("Failed to solve Cloudflare challenge")
 return ChallengeResult(False, cf\_detected, status)

 except Exception as e:
 self.log\_message(f"Error solving Cloudflare challenge: {e}")
 return ChallengeResult(False, cf\_detected, status)

 async def get\_cookies\_and\_user\_agent(self, context, page) -> Optional\[Dict\[str, Any\]\]:
 try:
 cookies = await context.cookies()
 cookie\_dict = {c\["name"\]: c\["value"\] for c in cookies}
 user\_agent = await page.evaluate("navigator.userAgent")
 return {"cookies": cookie\_dict, "user\_agent": user\_agent}
 except Exception as e:
 self.log\_message(f"Error getting cookies and user agent: {e}")
 return None

 async def \_stable\_html(self, page) -> str:
 """Return page.content() once its size stops changing, so JS renders deterministically.

 Polls instead of relying on networkidle (Playwright has no networkidle2 and idle
 can hang on pages with persistent connections). Bounded by HTML\_SETTLE\_MAX\_SECONDS.
 """
 try:
 await page.wait\_for\_load\_state("load", timeout=DEFAULT\_TIMEOUT\_MS)
 except Exception:
 pass

 html = await page.content()
 if HTML\_SETTLE\_STABLE\_ROUNDS <= 0 or HTML\_SETTLE\_POLL\_SECONDS <= 0:
 return html

 deadline = asyncio.get\_event\_loop().time() + HTML\_SETTLE\_MAX\_SECONDS
 stable = 0
 while stable < HTML\_SETTLE\_STABLE\_ROUNDS and asyncio.get\_event\_loop().time() < deadline:
 await asyncio.sleep(HTML\_SETTLE\_POLL\_SECONDS)
 try:
 current = await page.content()
 except Exception:
 break
 if len(current) == len(html):
 stable += 1
 else:
 stable = 0
 html = current
 return html

 async def get\_html\_content\_and\_cookies(self, context, page, status\_code: int = 200) -> Optional\[Dict\[str, Any\]\]:
 try:
 html = await self.\_stable\_html(page)
 cookies = await context.cookies()
 cookie\_dict = {c\["name"\]: c\["value"\] for c in cookies}
 user\_agent = await page.evaluate("navigator.userAgent")
 return {
 "cookies": cookie\_dict,
 "user\_agent": user\_agent,
 "html": html,
 "url": page.url,
 "status\_code": status\_code,
 }
 except Exception as e:
 self.log\_message(f"Error getting HTML content and cookies: {e}")
 return None

 @staticmethod
 def \_is\_trustworthy(cookies: Dict\[str, str\], cf\_detected: bool) -> bool:
 """A CF-detected result is only trustworthy once a cf\_clearance cookie exists."""
 if not cf\_detected:
 return True
 return bool(cookies.get("cf\_clearance"))

 async def \_read\_valid\_cache(self, key: str, proxy: Optional\[str\]):
 """Return a still-valid cache entry, or None — invalidating it if the proxy exit IP rotated."""
 cached = self.cookie\_cache.get(key)
 if not cached:
 return None
 if IP\_CHECK\_ENABLED and cached.exit\_ip:
 current = await get\_exit\_ip(proxy)
 if current and current != cached.exit\_ip:
 self.log\_message(f"Proxy exit IP changed ({cached.exit\_ip} -> {current}); invalidating cookies for {key}")
 self.cookie\_cache.invalidate(key)
 return None
 return cached

 async def \_run\_in\_browser(self, url, proxy, key, \*, restore\_cookies, extractor):
 """Shared browser skeleton: launch, solve, extract, cache. Returns the extractor dict or None."""
 cached\_ua = None
 cached\_cookies = None
 if restore\_cookies:
 cached = await self.\_read\_valid\_cache(key, proxy)
 if cached:
 cached\_cookies = cached.cookies
 cached\_ua = cached.user\_agent
 self.log\_message(f"Found cached cookies for {url}")

 async with \_browser\_semaphore():
 context = None
 try:
 context, page = await self.setup\_browser(proxy, user\_agent=cached\_ua)

 if cached\_cookies:
 self.log\_message("Restoring cached cookies...")
 cookie\_list = \[{"name": name, "value": value, "url": url} for name, value in cached\_cookies.items()\]
 await context.add\_cookies(cookie\_list)

 result = await self.solve\_cloudflare\_challenge(url, page)
 success, cf\_detected, status = result
 if success:
 data = await extractor(context, page, status)
 if data and self.\_is\_trustworthy(data\["cookies"\], cf\_detected):
 exit\_ip = await get\_exit\_ip(proxy) if IP\_CHECK\_ENABLED else None
 self.cookie\_cache.set(key, data\["cookies"\], data\["user\_agent"\], exit\_ip=exit\_ip)
 return data
 if data:
 self.log\_message("CF detected but no cf\_clearance cookie -- not caching")
 return None
 except Exception as e:
 self.log\_message(f"Error running browser for {url}: {e}")
 return None
 finally:
 await self.cleanup\_browser(context)

 async def get\_or\_generate\_cookies(self, url: str, proxy: Optional\[str\] = None) -> Optional\[Dict\[str, Any\]\]:
 """Get cached cookies or generate new ones."""
 hostname = urlparse(url).netloc
 key = cache\_key(hostname, proxy)

 cached = await self.\_read\_valid\_cache(key, proxy)
 if cached:
 return {"cookies": cached.cookies, "user\_agent": cached.user\_agent}

 async with \_inflight\_lock(key):
 # another waiter may have populated the cache while we queued
 cached = await self.\_read\_valid\_cache(key, proxy)
 if cached:
 return {"cookies": cached.cookies, "user\_agent": cached.user\_agent}

 self.log\_message(f"No cached cookies for {key}, generating new ones...")

 async def extractor(context, page, status):
 return await self.get\_cookies\_and\_user\_agent(context, page)

 return await self.\_run\_in\_browser(url, proxy, key, restore\_cookies=False, extractor=extractor)

 async def get\_or\_generate\_html(self, url: str, proxy: Optional\[str\] = None, bypass\_cache: bool = False) -> Optional\[Dict\[str, Any\]\]:
 """Get HTML content along with cookies (cached or fresh)."""
 hostname = urlparse(url).netloc
 key = cache\_key(hostname, proxy)

 self.log\_message(f"Getting HTML content for {url}...")

 # No in-flight lock here: HTML must be fetched fresh per request, so concurrent
 # requests run in parallel (bounded by the semaphore) rather than serializing.
 async def extractor(context, page, status):
 return await self.get\_html\_content\_and\_cookies(context, page, status\_code=status)

 return await self.\_run\_in\_browser(url, proxy, key, restore\_cookies=not bypass\_cache, extractor=extractor)

 async def cleanup\_browser(self, context) -> None:
 """Close the context (and its underlying browser). Never raises; never leaks."""
 if context is not None:
 try:
 # shield+timeout so a hung close (or outer cancellation) can't
 # leave the browser process running or block us forever
 await asyncio.wait\_for(asyncio.shield(context.close()), timeout=CONTEXT\_CLOSE\_TIMEOUT\_SECONDS)
 except Exception as e:
 self.log\_message(f"Error closing context: {e}")

 async def cleanup(self) -> None:
 """Backward compatibility method - no longer stores browser instances."""
 pass