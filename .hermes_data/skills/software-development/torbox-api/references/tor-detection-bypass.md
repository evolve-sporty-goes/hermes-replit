# Tor Detection Bypass — Techniques Compared

> **Status: RESEARCH** — 2026-06-28 session. Tor exit nodes are blocked by Cloudflare on `db.torbox.app`. This file catalogs bypass approaches.

## Problem

Tor exit IPs are on Cloudflare's real-time blocklist. Any request through Tor to a Cloudflare-protected site gets a JS challenge page that `curl` cannot solve.

## Techniques Compared

| Technique | CF Bypass? | Tor IP Hidden? | Complexity | Notes |
|-----------|-----------|----------------|------------|-------|
| **Tor + curl** | ❌ JS challenge | ✅ | Low | Fails — curl can't execute JS |
| **Tor + FlareSolverr + PySocks** | ✅ | ✅ | Medium | FlareSolverr solves JS challenge, replays cookie via PySocks |
| **Tor + Playwright (native)** | ⚠️ Partial | ✅ | Low | Playwright auto-solves on `page.goto()` but Tor exit still flagged for payment/subscription |
| **Camoufox + Tor** | ❌ | ✅ | Low | `geoip=True` spoofs fingerprint but IP is still blocked |
| **Camoufox + residential proxy + `geoip=True`** | ✅ | ✅ (residential IP) | Low | **Best for interactive browser automation** — clean IP + matching fingerprint |
| **Camoufox + `pproxy` SOCKS5 forward** | ❌ | ⚠️ (UDP leak) | Medium | GitHub issue #368: no native SOCKS5, WebRTC leaks real IP |

## Recommended Approaches by Use Case

### Raw API calls through Tor (signup, magic link)
→ **FlareSolverr + PySocks** (see `torbox-tor-signup.sh`)
```
FlareSolverr (headless Chrome + Tor) → cf_clearance cookie
→ Python urllib + PySocks → POST with cookie through Tor
```

### Interactive browser automation (dashboard, settings, trial)
→ **Camoufox + residential proxy + `geoip=True`** (NOT Tor)
```
Camoufox(geoip=True, proxy={"server": "socks5://residential:IP"})
→ page.goto() auto-solves CF (clean IP, matching fingerprint)
```

### Hybrid (Tor signup → clean IP for dashboard)
→ **FlareSolverr signup via Tor** → **Camoufox + residential for dashboard**
- Signup doesn't need a clean IP (Supabase API via FlareSolverr)
- Dashboard/trial activation needs clean residential IP (Tor exits flagged for payment)

## Free Residential Proxy Sources

| Source | Endpoint | Type | Reliability |
|--------|----------|------|-------------|
| ProxyScrape | `https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000&country=all&ssl=all&anonymity=all` | SOCKS5 | ~50% alive |
| Webshare | `https://www.webshare.io/features/free-proxy` | SOCKS5 (10 free) | Good |
| IPRoyal | `https://iproyal.com/free-proxy-list/` | HTTP/SOCKS5 | Medium |

Always pass `geoip=True` with any proxy to Camoufox — it auto-spoofs timezone/locale/WebRTC to match the proxy IP's region.

## Key Insight

**Camoufox `geoip=True` solves the FINGERPRINT leak, not the IP block.** If the IP itself is blacklisted (Tor exits, known datacenter ranges), no amount of fingerprint spoofing helps. You need a clean IP (residential) for Cloudflare-protected sites. Tor is only viable when you can solve the JS challenge separately (FlareSolverr) and replay cookies through PySocks.
