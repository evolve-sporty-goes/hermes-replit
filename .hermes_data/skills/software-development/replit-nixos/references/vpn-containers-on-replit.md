# VPN Containers on Replit (gluetun, WireGuard, OpenVPN)

VPN tunnel containers (gluetun, PiVPN, etc.) **do not work** on Replit's Docker environment due to kernel-level networking restrictions.

## Symptom

Container starts, authenticates to VPN provider, fails during routing setup:

```
ERROR setting up routing: adding routes for inbound traffic from default IP:
adding rule: adding rule for default route interface eth0, gateway 172.17.0.1,
and family v4: listing rules: netlink receive: operation not supported
INFO Shutdown successful
```

The container exits immediately after.

## Root Cause

Replit's Docker daemon runs on a kernel that **blocks netlink `RTM_GETRULE` / `RTM_NEWRULE` operations** even with `--cap-add=NET_ADMIN`. VPN containers need these to:
- Add policy-based routing rules (route VPN traffic through tunnel interface)
- Set up the kill switch (block all non-VPN traffic)

This is beyond `NET_ADMIN` — it requires unconfined network namespace admin (`net_admin` on an unrestricted kernel).

## Additional Constraint

`/dev/net/tun` does not exist and cannot be created without `mknod` (requires root/cap_sys_mknod). VPN containers would either need:
- Pre-existing `/dev/net/tun` device (not present)
- WireGuard-go (userspace WireGuard) — not supported by gluetun

## Workaround

**Run VPN containers on a real VPS** (Hetzner, DigitalOcean, Vultr, etc.) where:
- Full `NET_ADMIN` is unrestricted
- `/dev/net/tun` is available
- Netlink operations work

Alternatively, connect through a remote SOCKS5/SSH tunnel hosted on a VPS.

## Example: What Was Tried (Failed)

```bash
# This fails on Replit with "netlink receive: operation not supported"
docker run -d --name gluetun --cap-add=NET_ADMIN \
  -e VPN_SERVICE_PROVIDER=protonvpn \
  -e VPN_TYPE=wireguard \
  -e WIREGUARD_PRIVATE_KEY=<key> \
  -e SERVER_COUNTRIES="United States" \
  -e FREE_ONLY=on \
  -p 8888:8888/tcp -p 1080:1080/tcp \
  -v /tmp/gluetun:/gluetun \
  qmcgaw/gluetun
```

The same command works fine on a standard Linux host with Docker.

## Debugging Tip

If you see `netlink receive: operation not supported` in Docker logs — stop. No env var, capability flag, or device mount will fix it. The kernel blocks it. Move to a different host.
