# wireproxy Config Examples for Each Provider

## ProtonVPN Free (US/NL/JP, Unlimited)

```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = <server-public-key>
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
```

**Source**: Download from ProtonVPNVPNVP dashboard → Downloads → WireGuard → pick free server

---

## Cloudflare WARP (wgcf)

```bash
# Generate once
wgcf register && wgcf generate
# → wgcf-profile.conf
```

```ini
# Extract from wgcf-profile.conf:
[Interface]
PrivateKey = <from wgcf-profile.conf>
Address = 172.16.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = engage.cloudflareclient.com:2408
AllowedIPs = 0.0.0.0/0, ::/0

[Socks5]
BindAddress = 127.0.0.1:40000
```

**Note**: WARP Peer PublicKey is constant. Endpoint uses hostname (resolves to anycast).

---

## Mullvad (Paid, €5/mo)

```bash
# Download for specific region
wget -O mullvad.conf "https://api.mullvad.net/wg/config/<account-number>/<country-code>/<city-code>"
```

```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.x.x.x/32
DNS = 10.x.x.1

[Peer]
PublicKey = <server-public-key>
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
```

---

## Windscribe Free (10-15GB/mo)

```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.x.x.x/32
DNS = 10.x.x.1

[Peer]
PublicKey = <server-public-key>
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
```

**Source**: Windscribe dashboard → WireGuard config generator

---

## Generic Template

```ini
[Interface]
PrivateKey = <base64-encoded-private-key>
Address = <interface-ip>/32
DNS = <dns-ip>

[Peer]
PublicKey = <base64-encoded-server-public-key>
Endpoint = <host-or-ip>:<port>
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
# Optional auth:
# Username = user
# Password = pass

# Optional HTTP proxy (port 40001):
# [http]
# BindAddress = 127.0.0.1:40001
```

---

## Multi-Provider Rotation Script

```bash
#!/bin/bash
# rotate-proxy.sh — switch between configs

CONFIGS=("wireproxy-proton-us.conf" "wireproxy-proton-nl.conf" "wireproxy-warp.conf")

for cfg in "${CONFIGS[@]}"; do
    pkill wireproxy
    ./wireproxy -c "$cfg" &
    sleep 5
    IP=$(curl -s --socks5 127.0.0.1:40000 https://api.ipify.org)
    echo "$cfg → $IP"
    # Test target site
    curl -s --socks5 127.0.0.1:40000 https://torbox.app >/dev/null && echo "✓ torbox works" && break
done
```