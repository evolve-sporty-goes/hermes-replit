# Docker on Replit NixOS

Docker is available and functional on Replit despite the "no sudo / no systemd" constraint. The Docker daemon is managed by Replit's infrastructure and persists across container restarts.

## Verified Facts

| Property | Value |
|---|---|
| **Docker version** | 27.5.1 |
| **Storage driver** | overlay2 |
| **Buildx** | v0.23.0 |
| **Compose** | v2.36.0 |
| **Binary path** | `/nix/store/.../replit-runtime-path/bin/docker` |

## Constraints & Workarounds

### No IPv6 in Containers

The container network stack does not support IPv6. Services that default to binding `[::]:PORT` (nginx, etc.) fail with:
```
nginx: [emerg] socket() [::]:3000 failed (97: Address family not supported by protocol)
```

**Fix for linuxserver images:** pass `-e DISABLE_IPV6=true` — their init system regenerates nginx configs to bind IPv4 only.

**Fix for other images:** override the service config or entrypoint to bind `0.0.0.0` instead of `::`.

### Port Mapping

Ports must be declared in `.replit` under `[[ports]]`:
```toml
[[ports]]
localPort = 3000
externalPort = 3000
exposeLocalhost = true
```

Without this, the port is only accessible internally.

### Persistence

- Container state survives Replet restarts (Docker daemon persists).
- Volume data survives only if mounted under `~/workspace/`.
- Use `--restart unless-stopped` for auto-restart.

### Shared Memory

Browser containers need `--shm-size 1g`–`2g` (default 64MB is too small for Chromium/Firefox).

## Example: linuxserver/firefox

```bash
docker run -d \
  --name firefox \
  -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC \
  -e DISABLE_IPV6=true \
  -p 3000:3000 -p 3001:3001 \
  -v ~/workspace/firefox-config:/config \
  --shm-size 1g --restart unless-stopped \
  lscr.io/linuxserver/firefox:latest
```

Access at `http://localhost:3000` (or external port 3000).

## Example: jlesage/firefox

```bash
docker run -d \
  --name firefox \
  -p 5800:5800 -p 5900:5900 \
  -e VNC_PASSWORD=password \
  --shm-size 2g --restart unless-stopped \
  jlesage/firefox:latest
```

Access noVNC at `http://localhost:5800`, VNC on port 5900.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `socket() [::]:PORT failed (97)` | IPv6 not available | `-e DISABLE_IPV6=true` or bind IPv4 only |
| Container exits immediately | Port conflict or missing env | Check `docker logs <name>` |
| `Cannot connect to Docker daemon` | Daemon not ready | Wait and retry; Replit manages it |
| Browser crashes in container | `/dev/shm` too small | Add `--shm-size 1g` or larger |
