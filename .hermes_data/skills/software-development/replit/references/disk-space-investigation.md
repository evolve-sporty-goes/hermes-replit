# Disk Space Investigation on Replit

## Quick triage commands

When the user asks "how much space" or "what's using disk":

```bash
# Overview: filesystem free space
df -h /home/runner

# Workspace breakdown (top-level dirs)
du -sh /home/runner/workspace/ /home/runner/workspace/* 2>/dev/null | sort -rh | head -20

# Drill into a specific directory
du -sh /home/runner/workspace/.cache/* /home/runner/workspace/.cache/.* 2>/dev/null | sort -rh | head -10

# Full home breakdown
du -sh /home/runner/* /home/runner/.* 2>/dev/null | sort -rh | head -15
```

## Replit disk layout

- `/home/runner/workspace/` — persistent, survives redeploy (the only persistent dir)
- `/home/runner/.cache/` — persistent but outside workspace (good for caches)
- `/home/runner/.hermes_data/` — persistent, Hermes state
- `/nix/store/` — ephemeral, Nix packages (regenerated on deploy)
- `/tmp/` — ephemeral

The overlay filesystem at `/home/runner` has 32G total, ~31G free as of 2026-06.

## Common workspace space hogs

| Directory | Typical size | Notes |
|-----------|-------------|-------|
| `.cache/camoufox/` | 1.3G | Firefox fonts + binaries; move to `/home/runner/.cache/` |
| `.cache/uv/` | 530M | Python package archives |
| `.cache/pip/` | 100M | pip HTTP cache |
| `.pythonlibs/` | 300M+ | Installed Python packages |
| `.hermes_data/` | 150M+ | Hermes state, logs, sessions |
| `.git/` | varies | Can grow large with history |

## Moving a cache out of workspace

See the "Managing XDG Environment Variables on Replit" section in the main SKILL.md. The pattern is: move dir → update both replit env files → export in current session.

## When to investigate

- User asks about disk/space
- Build fails with "no space left"
- Workspace feels slow (large git index, many cached files)
- Deploy fails due to size limits
