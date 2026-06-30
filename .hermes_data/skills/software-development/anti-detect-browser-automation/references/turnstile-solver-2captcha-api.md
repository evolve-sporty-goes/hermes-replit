# Turnstile Solver (2captcha-compatible API)

Reference: [icemellow-me/turnstile-solver](https://github.com/icemellow-me/turnstile-solver)

## Overview

Self-hosted Cloudflare Turnstile solver exposing a **2captcha-compatible API**.
Useful as a drop-in replacement for 2captchaанти-captcha, AntiCaptcha, etc. in any
tool that speaks the 2captcha protocol.

**V2** (`solver-server-v2.py`, 651 lines): nodriver primary + camoufox fallback.
**V1** (`solver-server.py`): Playwright + CaptchaPlugin (deprecated, still works).

## Architecture

```
POST /in.php  → queue task → nodriver (Chromium/CDP) → camoufox (Firefox) → token
GET  /res.php ← poll for result
GET  /health  ← health check
```

### Dual-engine

| Engine | Browser | Role | Speed |
|---|---|---|---|
| `nodriver` | Chromium via CDP | Primary (faster launch, lower RAM) | ~5–10s |
| `camoufox` | Hardened Firefox | Fallback (stronger anti-detect) | ~5–15s + cold start |

Auto-retry: each engine retries up to 30 attempts before failing. nodriver tries
first; on exhaustion camoufox takes over.

## Quick start

```bash
git clone https://github.com/icemellow-me/turnstile-solver /tmp/turnstile-solver
cd /tmp/turnstile-solver
pip install -r requirements.txt   # nodriver, camoufox, aiohttp, playwright
python3 solver-server-v2.py --api-key YOUR_KEY --port 8878
```

Health check:
```bash
curl http://127.0.0.1:8878/health
# {"status":"ok","version":"2.0","queue":0,"solved":0,"active":0,"engines":["nodriver","camoufox"]}
```

### Docker

```bash
# Build
docker build -f Dockerfile.v2 -t turnstile-solver-v2 .

# Instance 1: plain-text responses (scripts, CLI)
docker run -d --name turnstile-solver-v2 --restart unless-stopped -p 8878:8878 \
  turnstile-solver-v2 python3 /app/solver-server-v2.py --api-key KEY --port 8878

# Instance 2: JSON mode (Chrome extension)
docker run -d --name captcha-ext-turnstile --restart unless-stopped -p 8822:8822 \
  turnstile-solver-v2 python3 /app/solver-server-v2.py --api-key KEY --port 8822
```

## API usage (2captcha-compatible)

### Submit task (plain-text mode, port 8878)

```bash
curl -X POST http://localhost:8878/in.php \
  -d 'key=YOUR_KEY&method=turnstile&sitekey=0x4AAAAAAABJFP0y4bGzwqHT&pageurl=https://demo.turnstile.workers.dev'
# OK|31337
```

### Submit task (JSON mode, port 8822)

```bash
curl -X POST http://localhost:8822/in.php \
  -d 'key=YOUR_KEY&method=turnstile&sitekey=0x4AAAA...&pageurl=https://demo.turnstile.workers.dev&json=1'
# {"status":1,"request":"31337"}
```

### Poll for result

```bash
# Plain
curl 'http://localhost:8878/res.php?key=YOUR_KEY&id=31337'
# OK|03AFcWeA...token...

# JSON
curl 'http://localhost:8822/res.php?key=YOUR_KEY&id=31337&json=1'
# {"status":1,"request":"03AFcWeA...token..."}
```

### Python example

```python
import urllib.request, urllib.parse, time, json

SERVER = "http://YOUR_SERVER:8878"
API_KEY = "YOUR_KEY"

# Submit
data = urllib.parse.urlencode({
    "key": API_KEY,
    "method": "turnstile",
    "sitekey": "0x4AAAAAAABJFP0y4bGzwqHT",
    "pageurl": "https://demo.turnstile.workers.dev",
}).encode()
resp = urllib.request.urlopen(f"{SERVER}/in.php", data)
task_id = resp.read().decode().split("|")[1]

# Poll
start = time.time()
while time.time() - start < 120:
    url = f"{SERVER}/res.php?key={API_KEY}&id={task_id}"
    resp = urllib.request.urlopen(url)
    result = resp.read().decode()
    if result.startswith("OK|"):
        token = result.split("|", 1)[1]
        print(f"Token: {token[:30]}...")
        break
    time.sleep(3)
```

### With 2captcha libraries

Any 2captcha-compatible client works by overriding the API URL:

```python
from twocaptcha import TwoCaptcha
solver = TwoCaptcha("YOUR_KEY")
solver.API_URL = "http://YOUR_SERVER:8878"
result = solver.turnstile(
    sitekey="0x4AAAA...",
    url="https://target-site.com"
)
```

## Command-line options

```
python3 solver-server-v2.py [OPTIONS]
  --api-key KEY       API key (or SOLVER_API_KEY env var)
  --port PORT         Server port (default: 8878)
  --max-sessions N    Max concurrent browsers (default: 2)
```

Environment variables:
- `SOLVER_API_KEY` — API key if not passed via `--api-key`
- `CHROME_PATH` — path to Chromium binary (default: `/usr/bin/chromium`)

## System requirements

- Python 3.10+
- `nodriver>=0.50` — needs Chromium installed
- `camoufox>=0.4` — downloads patched Firefox binary on first run (~80MB)
- Chromium at `/usr/bin/chromium` or set `CHROME_PATH`

### Debian/Ubuntu system deps
```bash
apt-get install -y chromium chromium-driver tesseract-ocr \
  fonts-liberation libnss3 libxss1 libasound2t64 \
  libatk-bridge2.0-0 libgtk-3-0 libgbm1 libx11-xcb1 xdg-utils xvfb
```

## Challenge type support

| Type | nodriver | camoufox | Notes |
|---|---|---|---|
| Non-interactive | ✅ ~5-10s | ✅ ~5-10s | Most common |
| Managed | ✅ | ✅ | CF decides interaction |
| Invisible | ✅ | ✅ | Runs in background |

## Troubleshooting

| Symptom | Fix |
|---|---|
| "nodriver failed to launch" | `which chromium` — install or set `CHROME_PATH` |
| "camoufox download failed" | First run needs internet; subsequent runs use cache |
| Empty token returned | Verify `sitekey` and `pageurl` match target; demo tokens (`XXXX.DUMMY...`) are valid responses |
| Slow first solve | Browser cold start — subsequent solves faster |
| Need higher throughput | Increase `--max-sessions` (more RAM) |

## Chrome extension integration

Paired with [captcha-solver-extension](https://github.com/icemellow-me/captcha-solver-extension):

| Instance | Port | Response format | Purpose |
|---|---|---|---|
| Original | 8878 | Plain-text (`OK\|id`) | Scripts, CLI, direct API |
| Extension | 8822 | JSON (`json=1`) | Chrome extension via Universal Solver (8844) |

## Difference from CloudflareBypassForScraping

| Feature | turnstile-solver | CloudflareBypassForScraping |
|---|---|---|
| Protocol | 2captcha-compatible | Custom REST API |
| Engine | nodriver + camoufox | CloakBrowser (custom Chromium) |
| Output | Turnstile token | Cookies/HTML/request mirroring |
| Use case | Drop-in 2captcha replacement | Scraping proxy, cookie extraction |
| Challenges | Turnstile only | CF Challenge + Turnstile |

Turnstile-solver gives you **tokens** (paste into Clerk/Cloudflare forms);
CloudflareBypassForScraping gives you **cookies + session** for headless HTTP clients.
Can be combined: bypass server for navigation, turnstile solver for token-bearing submits.
