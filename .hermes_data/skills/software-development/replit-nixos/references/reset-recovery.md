# Machine Reset Recovery

## Session: 2026-06-27

### What survives a reset
Everything under `/home/runner/workspace/` (git-tracked). This is the single source of truth.

### What's lost
- `~/.pythonlibs/` — all pip/uv-installed packages
- `~/.config/` — git config, playwright browsers, app configs
- `~/.cache/` — camoufox profile, pip wheels, curl cache
- `/tmp/` — anything there
- npm global packages (`npm i -g`)
- Running background processes
- Custom symlinks in home

### Recovery sequence
```bash
# 1. Run setup script (handles uv, hermes-agent, venv, webui, wrapper)
bash ~/workspace/hermes.sh

# 2. Reinstall any extra Python deps your workflows need
cd ~/workspace && uv pip install <extra-packages>

# 3. Reinstall npm globals
npm i -g firecrawl  # example

# 4. Reconfigure git if needed
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### Storage tip (user preference)
To keep workspace small, make cache ephemeral:
```bash
rm -rf ~/.cache && mkdir -p ~/.cache
# Don't set XDG_CACHE_HOME — tools default to ~/.cache (ephemeral)
```
This frees ~1.2 GB of workspace (camoufox profile, pip wheels).
