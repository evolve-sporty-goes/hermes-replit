# Replit NixOS Filesystem Layout

Snapshot from `df -h` on a live Replit container (2026-06-28).

## Full Partition Table

| Mount | Device | Size | Used | Avail | Use% | Writable |
|-------|--------|------|------|-------|------|----------|
| `/` | overlay | 4.0M | 0 | 4.0M | 0% | read-only |
| `/nix/store` | overlay | 256G | 2.4G | 252G | 1% | Nix-managed |
| `/home/runner` | overlay | 32G | 2.2G | 30G | 7% | ✅ persistent |
| `/home/runner/workspace` | /dev/vde | 256G | 2.4G | 252G | 1% | ✅ persistent |
| `/mnt/snix` | /dev/vdb | **1.8T** | 1.7T | **129G** | 93% | ❌ read-only |
| `/mnt/scratch` | /dev/vdc | 32G | 2.2G | 30G | 7% | ✅ writable |
| `/mnt/33088498-...` | /dev/vdc | 32G | 2.2G | 30G | 7% | ✅ writable |
| `/dev/shm` | shm | 3.9G | 0 | 3.9G | 0% | ✅ tmpfs |
| `/mnt/nix` | /dev/vde | 256G | 2.4G | 252G | 1% | Nix-managed |
| `/etc` | overlay | 232M | 232M | 0 | 100% | read-only |
| `/usr/bin` | overlay | 232M | 232M | 0 | 100% | read-only |
| `/mnt/nixmodules` | /dev/vda | 21G | 21G | 0 | 100% | read-only |

## Key Findings

### `/mnt/snix` is READ-ONLY despite showing 129GB free
- `df -h` reports 129GB available, but `touch /mnt/snix/testfile` fails with "Read-only file system".
- **Do not rely on `/mnt/snix` for storage.** It's a reporting artifact — the space exists on the device but the filesystem is mounted read-only.
- Always **test writability** before assuming a mount is usable: `touch "$mnt/.wtest" && rm "$mnt/.wtest"`.

### Largest ACTUALLY writable partition: `/home/runner/workspace` (252GB free)
- The biggest **writable** space available.
- Persistent — survives restarts.
- Backed by `/dev/vde`.

### Writable scratch space: `/mnt/scratch` (30GB free per df, ~3GB real)
- Confirmed writable via real write test (86.3 MB/s initial, 138 MB/s sustained).
- **Real limit ~3GB** — `/mnt/scratch` and `/mnt/33088498-...` share the same `/dev/vdc` device (32GB total, shared with `/home/runner`). A 10GB write test failed at ~3.1GB. The 30GB shown by `df` is the device size, not the per-mount quota.
- Ephemeral — likely wiped on restart.
- Good for small temporary files, NOT for large data despite df showing 30GB.

### All confirmed-writable mounts (2026-06-28 verification)
| Mount | df Free | Real Free | Persistent | Speed |
|-------|---------|-----------|------------|-------|
| `/home/runner/workspace` | 252G | **40G+ tested** | ✅ | 229-307 MB/s |
| `/home/runner` | 30G | ~30G | ✅ | — |
| `/mnt/scratch` | 30G | **~3GB** | ❌ | 86-138 MB/s |
| `/mnt/33088498-...` | 30G | **~3GB** (shared) | ❌ | — |
| `/dev/shm` | 3.9G | 3.9G | ❌ | RAM-backed |
| `/run` | 50M | 50M | ❌ | — |

### Persistent storage: `/home/runner/workspace` (252GB free)
- The ONLY user-writable persistent directory that survives restarts.
- Backed by `/dev/vdd` (256GB device, thin-provisioned).
- **Thin-provisioned behavior:** Deleted files may NOT reclaim space at the block level. A 40GB file deleted after `rm` still showed 43GB "used" in `df` — the storage backend doesn't know blocks are free. This is phantom allocation; real data writes will still succeed up to the 256GB ceiling.
- **Large writes can crash the container:** Attempting to write 50GB in a single `dd` caused a forced restart before cleanup could run. Use `timeout` to cap large writes: `timeout 200 dd if=/dev/zero of=... bs=1M count=N`.

### No root access
- `/root` is **inaccessible** — `cd /root` returns "Permission denied".
- `sudo` is **not available** — cannot escalate privileges.
- Cannot change passwords of any user.
- Runs as unprivileged user `runner`.

### tmpfs /dev/shm
- 3.9GB shared memory — useful for fast temporary I/O.
- Ephemeral (wiped on restart).

## Practical Guidance

- **Need lots of temporary space?** Use `/mnt/snix` (129GB free).
- **Need persistence?** Use `/home/runner/workspace/` only.
- **Need fast scratch?** Use `/dev/shm` (3.9GB RAM-backed).
- **Cannot** write to `/etc`, `/usr/bin`, `/`, or `/root`.
- **Cannot** use `sudo` or `su` to escalate.
