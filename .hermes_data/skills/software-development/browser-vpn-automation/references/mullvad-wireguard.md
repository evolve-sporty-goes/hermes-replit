# Mullvad WireGuard for Automation

## Why Mullvad?
- **Same infrastructure** as Mozilla VPN / Firefox built-in VPN
- **No account needed** — anonymous account number only (€5/mo)
- **Native WireGuard configs** — works system-wide in containers
- **No data caps** — unlimited bandwidth
- **Headless-friendly** — no browser OAuth required

## Get WireGuard Config
```bash
# 1. Create account at mullvad.net (generates account number like 1234567890123456)
# 2. Download config:
wget -O mullvad.conf "https://api.mullvad.net/wg/config/<account-number>"

# Or specific region:
wget -O mullvad-us.conf "https://api.mullvad.net/wg/config/<account-number>/us"
wget -O mullvad-de.conf "https://api.mullvad.net/wg/config/<account-number>/de"

# All regions:
wget -O mullvad-all.conf "https://api.mullvad.net/wg/config/<account-number>/all"
```

## Container Setup (Docker/Replit/K8s)
```dockerfile
# Dockerfile
FROM ubuntu:24.04
RUN apt update && apt install -y wireguard curl
COPY mullvad.conf /etc/wireguard/mullvad.conf
CMD ["wg-quick", "up", "mullvad"]
```

```bash
# Replit / bare container:
apt update && apt install -y wireguard
wg-quick up mullvad.conf

# Verify:
wg show
curl https://api.ipify.org
```

## WireGuard Config Structure
```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.x.x.x/32
DNS = 10.64.0.1

[Peer]
PublicKey = <mullvad-public-key>
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

## Multiple Configs (Region Rotation)
```bash
# Download configs for multiple regions
for region in us de fr jp sg; do
  wget -O "mullvad-$region.conf" "https://api.mullvad.net/wg/config/<account>/$region"
done

# Switch regions:
wg-quick down mullvad-us && wg-quick up mullvad-de
```

## Playwright/Selenium Integration
```python
# Python + Playwright: all traffic goes through WireGuard automatically
# No proxy config needed — system-wide tunnel

from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("https://api.ipify.org")
        print(await page.text_content("body"))  # Shows Mullvad exit IP
        await browser.close()

# Same for requests, selenium, curl — all use WireGuard tunnel
```

## SOCKS5 Proxy Alternative (if needed)
```bash
# Run WireGuard + SOCKS5 proxy for apps that need explicit proxy
# (Most don't — system tunnel works transparently)

# Using Dante or similar:
# docker run -d --cap-add=NET_ADMIN --device=/dev/net/tun \
#   -v $(pwd)/mullvad.conf:/etc/wireguard/mullvad.conf \
#   -p 1080:1080 \
#   ghcr.io/kizzx2/dante-wireguard:latest
```

## Account Management
```bash
# Check account status:
curl "https://api.mullvad.net/www/accounts/<account-number>/"

# Add time (from Mullvad dashboard or CLI):
# mullvad account add <account-number> <voucher-code>

# List devices:
curl "https://api.mullvad.net/www/accounts/<account-number>/devices/"
```

## Replit-Specific Notes
- Replit containers may not have `/dev/net/tun` → WireGuard kernel module fails
- **Workaround**: Use `wireguard-go` (userspace) or Tailscale userspace mode
- Or: Use Mullvad's SOCKS5 proxy endpoint (if available) instead of WireGuard
- Test: `ls /dev/net/tun` — if missing, kernel WireGuard won't work

```bash
# Userspace WireGuard (wireguard-go):
go install github.com/wireguard/wireguard-go@latest
wireguard-go wg0
wg setconf wg0 mullvad.conf
ip link set wg0 up
ip route add 0.0.0.0/0 dev wg0
```

## Cost Comparison
| Solution | Cost | Data Cap | Scope | Headless |
|----------|------|----------|-------|----------|
| Firefox built-in VPN | Free | 50 GB/mo | Browser only | ⚠️ Limited |
| Mozilla VPN CLI → WireGuard | Free* | 50 GB/mo* | System-wide | ✅ After setup |
| Mullvad WireGuard | €5/mo | None | System-wide | ✅ Native |

*Requires Mozilla account; same 50GB cap applies to Firefox VPN tier

## Sources
- Mullvad API: https://api.mullvad.net
- WireGuard: https://www.wireguard.com
- Mozilla VPN = Mullvad infrastructure (confirmed by Mozilla, Fastly, Mullvad)