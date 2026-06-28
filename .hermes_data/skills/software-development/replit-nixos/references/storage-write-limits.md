# Storage Write Limits (2026-06-28)

Empirical tests of actual writable limits on Replit NixOS storage.

## Mount Points

| Mount | df Shows | Real Writable | Notes |
|-------|----------|---------------|-------|
| `/home/runner/workspace` | 256G total, ~252G free | Yes (persistent) | Per-write cap ~48GB |
| `/home/runner` | 32G total, ~30G free | Yes (persistent) | Separate overlay |
| `/mnt/scratch` | 30G free | ~3GB | Shares /dev/vdc with /home/runner |
| `/mnt/snix` | 1.8T total, 129G free | Read-only | df lies, cannot write |
| `/dev/shm` | 3.9G | Yes (tmpfs/RAM) | Ephemeral |
| `/run` | 50M | Yes (tmpfs) | Ephemeral |

## Write Speed Tests

| Mount | Test Size | Speed | Duration |
|-------|-----------|-------|----------|
| /mnt/scratch | 1GB | 86.3 MB/s | 12.4s |
| /mnt/scratch | 3GB | 138 MB/s | 22.5s (stopped at cap) |
| /home/runner/workspace | 1GB | 74.7 MB/s | 14.4s |
| /home/runner/workspace | 20GB | 307 MB/s | 70s |
| /home/runner/workspace | 40GB | 229 MB/s | 188s |
| /home/runner/workspace | 48GB | 221 MB/s | 233s (cap reached) |
| /home/runner/workspace | 100GB attempt | - | Stopped at ~48GB |

## Key Findings

1. Per-write cap at ~48GB: single dd process stops at ~48GB regardless of requested size.
2. Append (>>) doesn't work after cap - file stays at ~48GB.
3. Thin-provisioned phantom space: after writing+deleting 40GB, df still showed 43GB used.
4. Crash risk: writing >40GB without timeout caused forced restart. Always use timeout.
5. Safe pattern: timeout 400 dd if=/dev/zero of=bigfile bs=8M count=12800

## No Root Access

- sudo not installed
- /root permission denied
- Cannot change user passwords
- Runs as unprivileged runner user
