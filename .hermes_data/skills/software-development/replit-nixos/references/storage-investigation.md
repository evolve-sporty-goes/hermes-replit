# Storage Investigation Notes

## Session: 2026-06-27

### Real disk usage (~4.20 GB in workspace)
| Path | Size | Notes |
|---|---|---|
| `.cache/` | 1.2 GB | Cargo builds, camoufox, pip wheels — persistent via XDG_CACHE_HOME |
| `.pythonlibs/` | 310 MB | uv-managed Python deps — ephemeral |
| `.hermes_data/` | ~167 MB | Agent state (memory, sessions, skills, logs) — persistent |
| `.local/` | ~75 MB | Wrapper scripts (hermes) — persistent |
| `.git/` | ~61 MB | — |

### Key corrections to initial assumptions
1. `.cache/` is **persistent** — Replit sets `XDG_CACHE_HOME=/home/runner/workspace/.cache`
2. `/mnt/nix/` is writable but should not be used for arbitrary storage
3. `~/.local/bin/` is symlinked into workspace — persistent despite being "dot-local"

## Git push workaround
```bash
cd /home/runner/workspace
git push "https://$(cat .pat | tr -d '\n')@github.com/evolve-sporty-goes/hermes-replit.git" main
```
- HTTPS askpass fails in Replit (no interactive prompt)
- Token stored in `.pat`, stripped via `tr -d '\n'`
- This is the only working pattern tested this session

## Binary wrapper pattern
```bash
# WRONG — symlink fails (venv not activated)
ln -sf /path/to/venv/bin/hermes ~/.local/bin/hermes

# CORRECT — wrapper calls venv python directly
cat > ~/.local/bin/hermes << 'EOF'
#!/bin/bash
exec /path/to/venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/.local/bin/hermes
```
