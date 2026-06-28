# xrdp on Replit NixOS

xrdp runs natively on Replit via Nix packages — no Docker required. It listens on port 3389 (standard RDP) and works for remote desktop connections.

## Verified Facts

| Property | Value |
|---|---|
| **xrdp version** | 0.9.25.1 |
| **Nix store path** | `/nix/store/0yflpakl423g9mxbs08f2l8h6dfs6qsi-xrdp-0.9.25.1` |
| **Binaries** | `xrdp`, `xrdp-sesman`, `xrdp-chansrv`, `xrdp-dis`, `xrdp-genkeymap`, `xrdp-keygen`, `xrdp-sesadmin`, `xrdp-sesrun` |
| **Default port** | 3389 (RDP), 3350 (sesman internal) |
| **Also in Nix** | `xorgxrdp-0.10.2`, `pulseaudio-module-xrdp-0.7` |

## Critical: Log Path Issue

xrdp **fails immediately** if it cannot write to its log file. The default config uses `LogFile=xrdp.log` (relative path) and `EnableSyslog=true` — both fail in Replit's environment with:

```
Could not start log
error opening log file [The log is not properly started]. quitting.
```

**Fix:** Copy configs to workspace and set absolute writable log paths:

```bash
mkdir -p ~/workspace/xrdp-config
cp /nix/store/*-xrdp-*/etc/xrdp/*.ini ~/workspace/xrdp-config/
sed -i 's|LogFile=xrdp.log|LogFile=/home/runner/workspace/xrdp-config/xrdp.log|' ~/workspace/xrdp-config/xrdp.ini
sed -i 's|EnableSyslog=true|EnableSyslog=false|' ~/workspace/xrdp-config/xrdp.ini
```

## Running

```bash
# Start sesman first (session manager daemon)
xrdp-sesman -c ~/workspace/xrdp-config/sesman.ini &

# Start xrdp main daemon
xrdp --nodaemon -c ~/workspace/xrdp-config/xrdp.ini &
```

Both run as background processes (use `terminal(background=true)` in Hermes).

## Authentication

xrdp uses PAM by default. On Replit:
- The `runner` user (uid=1000) can authenticate
- No root/sudo — PAM `pam_unix` may restrict logins
- If auth fails, configure `pam_permit` or ensure the user has a valid shell

## Limitations

| Limitation | Detail |
|---|---|
| **No systemd** | Must run `xrdp-sesman` + `xrdp` manually as background processes |
| **No GPU** | No `/dev/dri` — software rendering only |
| **No pulseaudio** | Audio won't work unless pulseaudio-module-xrdp is configured |
| **Port 3389** | Add to `.replit` as `[[ports]]` for external RDP client access |
| **No D-Bus session** | Some desktop apps may fail without a session bus |

## Port Mapping for External Access

```toml
[[ports]]
localPort = 3389
externalPort = 3389
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Could not start log` | Log path not writable | Copy configs to workspace, set absolute `LogFile` path |
| `xrdp-sesman is already running` | Stale PID file | `rm -f /var/run/xrdp-sesman.pid` |
| Connection refused | Firewall or port not mapped | Add `[[ports]]` entry in `.replit` |
| Auth failure | PAM restrictions | Check `/etc/pam.d/xrdp-sesman`, consider `pam_permit` |
