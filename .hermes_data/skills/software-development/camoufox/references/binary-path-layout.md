# Camoufox Binary Path Layout

The actual browser binary is NOT at `~/.cache/camoufox/camoufox` as some older docs suggest.

## Actual layout (observed 2025-2026)

```
~/.cache/camoufox/
├── config.json          # {"active_version": "browsers/official/<version>"}
├── browsers/
│   └── official/
│       └── <version>/   # e.g. 135.0.1-beta.24/
│           ├── camoufox      # <-- THE BINARY
│           ├── camoufox-bin
│           ├── libxul.so
│           ├── libmozgtk.so
│           ├── omni.ja
│           └── ... (many .so files, fonts, config)
```

## How to resolve programmatically

```python
import json, os
cache_dir = os.path.expanduser("~/.cache/camoufox")
with open(os.path.join(cache_dir, "config.json")) as f:
    active = json.load(f)["active_version"]
binary = os.path.join(cache_dir, active, "camoufox")
```

Or via CLI:

```bash
python -m camoufox path
```

This prints the install directory whose `browsers/<version>/camoufox` is the executable.

## Why this matters

When constructing `executable_path=` in `Camoufox(...)`, always resolve it from `config.json`. The active version changes when you `camoufox set official/prerelease` + `fetch`. Hardcoding any path will silently break on the next upgrade.
