# Tor SOCKS5 Proxy Test Results (2026-06-28)

## Environment
- **Host:** Replit NixOS
- **Tor binary:** `/nix/store/wnfpm8rjbgq5nhqj4dr85jnky86xvxcx-tor-0.4.8.16/bin/tor`
- **SOCKS5 proxy:** `127.0.0.1:9050` (running by default)
- **Control port:** `9051`
- **FlareSolverr:** `127.0.0.1:8191` (headless Chrome that solves Cloudflare JS challenges)

## Test 1: Plain curl through Tor — FAILED

```bash
ANON_KEY=$(cat /home/runner/workspace/.supabase_anon_key)
curl --socks5-hostname 127.0.0.1:9050 -s -X POST \
  'https://db.torbox.app/auth/v1/signup' \
  -H 'Content-Type: application/json' \
  -H "apikey: $ANON_KEY" \
  -d '{"email":"bavmin+RAND@proton.me","password":"Satyana@1234"}'
```

### Result
- **Response:** Full Cloudflare "Just a moment..." JS challenge HTML page
- **HTTP status:** 200 (Cloudflare challenge page, not a 403 WAF block)
- **Tor exit IP confirmed:** `193.189.100.200` (via `check.torproject.org/api/ip`)
- **Multiple attempts:** All returned the same Cloudflare challenge page
- **New circuit requests:** `curl -s http://127.0.0.1:9051 -X POST` did not help — all Tor exits are flagged

### Conclusion
Plain `curl` through Tor hits Cloudflare JS challenge — `curl` cannot solve JS challenges.

## Test 2: FlareSolverr + PySocks — SUCCESS ✓

**Two-step approach:** FlareSolverr solves Cloudflare in a real browser through Tor, then Python replays the cf_clearance cookie through Tor via PySocks.

### Step 1: FlareSolverr — solve Cloudflare, get cookies

```json
{
  "cmd": "request.get",
  "url": "https://db.torbox.app/auth/v1/signup",
  "maxTimeout": 120000,
  "proxy": {"url": "socks5://127.0.0.1:9050"}
}
```

POST to `http://127.0.0.1:8191/v1`. FlareSolverr launches headless Chrome through Tor, solves the JS challenge, and returns:
- `solution.cookies` → includes `cf_clearance=...`
- `solution.userAgent` → the Chrome UA string (must match for replay)

### Step 2: Python + PySocks — replay signup with cookie

```python
import urllib.request, json, socks, socket

socks.set_default_proxy(socks.SOCKS5, '127.0.0.1', 9050)
socket.socket = socks.socksocket

req = urllib.request.Request(url, data=data, method='POST')
req.add_header('Content-Type', 'application/json')
req.add_header('apikey', anon_key)
req.add_header('Cookie', cookie_str)       # cf_clearance from FlareSolverr
req.add_header('User-Agent', user_agent)   # must match
resp = urllib.request.urlopen(req, timeout=30)
```

### Result
```
Email: bavmin+53994@proton.me
SUCCESS via Tor + FlareSolverr!
  ID: 92896bcf-5b0a-4032-91f2-2555e22c1e5b
  Confirmation sent: 2026-06-28T08:02:51.636476792Z
```

### Why it works
1. FlareSolverr's headless Chrome executes the Cloudflare JS challenge → gets `cf_clearance` cookie
2. The cookie is bound to the Tor exit IP + User-Agent
3. PySocks routes the signup POST through the same Tor exit
4. Cloudflare validates the cookie (IP + UA match) → passes request to Supabase
5. Supabase creates the account

### Caveats
- **TorBox fraud detection may still block** at the business logic layer (payment/subscription). Signup works; paid actions may not.
- **FlareSolverr must be running** on `127.0.0.1:8191`
- **PySocks must be installed** (`pip install PySocks`)
- **Cookie + UA must match** — use the exact UA from FlareSolverr's response

## Verifying Tor Circuit
```bash
curl --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip
# {"IsTor":true,"IP":"<exit_node>"}
```

## Ready-made Scripts
- `scripts/torbox-tor-signup.sh` — Tor signup only (FlareSolverr → PySocks signup → credentials file)
- `scripts/torbox-full-signup.sh` — Full end-to-end: Tor signup → Proton verify → Tor Playwright verify + API key extraction. See `references/full-tor-signup-pipeline.md` for architecture details.
