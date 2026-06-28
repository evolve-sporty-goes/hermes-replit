# Tor + FlareSolverr Infrastructure on Replit

> **Verified: 2026-06-28** — How Tor and FlareSolverr are deployed on this Replit NixOS environment.

## Architecture

```
[Script] → Tor SOCKS5 (127.0.0.1:9050) → Tor network → internet
[Script] → FlareSolverr API (127.0.0.1:8191) → Docker container (--network host)
                                                    ↓
                                              Uses Tor via PROXY_URL env
```

## Tor

- **Binary**: `/nix/store/wnfpm8rjbgq5nhqj4dr85jnky86xvxcx-tor-0.4.8.16/bin/tor` (nix store)
- **SOCKS5 port**: 9050
- **Control port**: 9051 (for `SIGNAL NEWNYM` circuit rotation)
- **Config**: Temp file created at runtime (`/tmp/torrc.XXXXXX`)
- **Data dir**: `/tmp/tor-data`
- **Bootstrap time**: 2-4 minutes on Replit (directory fetches throttled)
- **Log**: `/tmp/tor.log`

### Starting Tor manually
```bash
TOR_BIN="/nix/store/wnfpm8rjbgq5nhqj4dr85jnky86xvxcx-tor-0.4.8.16/bin/tor"
TORRC=$(mktemp /tmp/torrc.XXXXXX)
cat > "$TORRC" << EOF
SocksPort 9050
ControlPort 9051
DataDirectory /tmp/tor-data
Log notice stderr
EOF
mkdir -p /tmp/tor-data
$TOR_BIN -f "$TORRC" &
# Wait for "Bootstrapped 100%" in /tmp/tor.log
```

### Verifying Tor
```bash
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
# {"IsTor":true,"IP":"xx.xx.xx.xx"}
```

### Rotating Tor circuit
```bash
# Send NEWNYM signal to get fresh exit IP
echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' | nc 127.0.0.1 9051
```

## FlareSolverr

- **Deployment**: Docker container (`ghcr.io/flaresolverr/flaresolverr:latest`)
- **Container name**: `flaresolverr`
- **API port**: 8191
- **Network mode**: `--network host` (so it can reach Tor at 127.0.0.1:9050)
- **Tor proxy**: Set via `PROXY_URL=socks5://127.0.0.1:9050` env var
- **Restart policy**: `unless-stopped`

### Starting FlareSolverr manually
```bash
docker rm -f flaresolverr 2>/dev/null || true
docker run -d \
  --name flaresolverr \
  --network host \
  --restart unless-stopped \
  -e PROXY_URL=socks5://127.0.0.1:9050 \
  -e LOG_LEVEL=info \
  ghcr.io/flaresolverr/flaresolverr:latest
# Wait for http://127.0.0.1:8191/v1 to respond
```

### Verifying FlareSolverr + Tor integration
```bash
curl -s -m 30 -X POST http://127.0.0.1:8191/v1 \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://check.torproject.org/api/ip","maxTimeout":30000}'
# Response HTML should contain "IsTor":true
```

## All-in-One Startup Script

```bash
bash scripts/start-tor-flare.sh
```

Handles: Tor bootstrap wait, FlareSolverr container start, health checks for both, idempotent (skips if running).

## Why This Setup

| Requirement | Solution |
|-------------|----------|
| Cloudflare JS challenge on `db.torbox.app` | FlareSolverr (headless Chrome) solves JS |
| Route through Tor for anonymity | FlareSolverr `PROXY_URL` → Tor SOCKS5 |
| FlareSolverr needs to reach Tor | `--network host` (container shares host network) |
| Raw HTTP POST through Tor | PySocks + cf_clearance cookie from FlareSolverr |
| Interactive browser through Tor | Playwright `proxy={"server": "socks5://127.0.0.1:9050"}` |

## Environment Constraints

- **No TUN/TAP** (`/dev/net/tun` missing) → VPN (OpenVPN, WireGuard, Proton VPN) **cannot work**
- **No `modprobe`** → cannot load kernel modules
- **No network namespace** (`unshare --net` fails) → cannot create `wg0` interface
- **Tor works** because it's userspace-only (SOCKS5 proxy, no kernel support needed)
- **Docker works** with `--network host` (shares host network stack)
- **OpenVPN binary exists** in nix store but cannot create TUN device → unusable
- **WireGuard tools exist** in nix store but cannot create interface → unusable

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Tor not bootstrapping | Directory fetches throttled | Wait up to 4 min, check `/tmp/tor.log` |
| FlareSolverr exits immediately | Port 8191 in use | `docker rm -f flaresolverr` then restart |
| FlareSolverr can't reach Tor | Container not on host network | Verify `--network host` in docker run |
| `IsTor:false` from FlareSolverr | PROXY_URL not set or wrong | Check `docker inspect flaresolverr` env vars |
| Cloudflare still blocks | Tor exit IP blacklisted | Expected — use FlareSolverr to solve JS challenge |
