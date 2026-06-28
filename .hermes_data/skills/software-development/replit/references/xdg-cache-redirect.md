# XDG Cache Redirect on Replit

## Camoufox Cache Migration (2026-06-27)

Camoufox (Firefox-based anti-fingerprint browser) stores its profile in `$XDG_CACHE_HOME/camoufox` — which defaults to `/home/runner/workspace/.cache/camoufox`. This directory is 1.3G (mostly bundled Firefox fonts and binaries), dominating the workspace's 2.5G total.

### Before

```
/home/runner/workspace/.cache/camoufox/  1.3G
/home/runner/workspace/.cache/uv/        530M
/home/runner/workspace/.cache/pip/       103M
Total workspace: 2.5G
```

### After

```
/home/runner/.cache/camoufox/            1.3G  (outside workspace)
/home/runner/workspace/.cache/uv/        530M
/home/runner/workspace/.cache/pip/       103M
Total workspace: 1.2G
```

### Steps Performed

1. Move the directory:
   ```bash
   mkdir -p /home/runner/.cache
   mv /home/runner/workspace/.cache/camoufox /home/runner/.cache/camoufox
   ```

2. Update Replit env files (both):
   ```bash
   # Shell format (latest)
   sed -i 's|declare -gx XDG_CACHE_HOME=/home/runner/workspace/.cache|declare -gx XDG_CACHE_HOME=/home/runner/.cache|' \
     /home/runner/workspace/.cache/replit/env/latest

   # JSON format (latest.json)
   sed -i 's|XDG_CACHE_HOME":"/home/runner/workspace/.cache"|XDG_CACHE_HOME":"/home/runner/.cache"|' \
     /home/runner/workspace/.cache/replit/env/latest.json
   ```

3. Export in current session:
   ```bash
   export XDG_CACHE_HOME=/home/runner/.cache
   ```

### Verification

```bash
# Confirm camoufox binary exists at new location
ls -la /home/runner/.cache/camoufox/camoufox

# Confirm env files updated
grep XDG_CACHE_HOME /home/runner/workspace/.cache/replit/env/latest
grep XDG_CACHE_HOME /home/runner/workspace/.cache/replit/env/latest.json

# Confirm workspace size reduced
du -sh /home/runner/workspace/
```

### Notes

- The `camoufox.cfg` file at `/home/runner/.cache/camoufox/camoufox.cfg` contains all Firefox prefs and is preserved by the move.
- No symlink needed — tools respect `XDG_CACHE_HOME` directly.
- If a tool hardcodes `~/.cache` instead of respecting `XDG_CACHE_HOME`, a symlink from `~/.cache/<tool>` to `/home/runner/.cache/<tool>` would be needed. Camoufox respects the env var.
- The `POETRY_CACHE_DIR` is explicitly set to `/home/runner/workspace/.cache/pypoetry` in Replit's env — this is independent of `XDG_CACHE_HOME` and was left unchanged.

### See also

- `references/disk-space-investigation.md` — full disk triage commands, Replit disk layout, and common workspace space hogs.
