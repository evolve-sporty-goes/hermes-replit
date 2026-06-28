# Canonical hermes.sh (as of 2026-06-27)

The setup script for the Replit NixOS environment. This is the source of truth for the correct ordering, patterns, and pitfalls.

```bash
#!/usr/bin/env bash
set -euo pipefail

unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
export UV_PYTHON_DOWNLOADS=manual

# 1. Install uv
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Clone or update hermes-agent
if [ ! -d "$HOME/hermes-agent" ]; then
    git clone https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent"
else
    git -C "$HOME/hermes-agent" pull
fi

# 3. Create venv + install deps
(
    cd "$HOME/hermes-agent"
    [ -d .venv ] || uv venv .venv
    uv pip install -e ".[all]"
)

# 4. Ensure ~/.config/bashrc adds bins to PATH for all interactive shells
BASHRC="$HOME/.config/bashrc"
if [ ! -f "$BASHRC" ] || ! grep -q "pythonlibs" "$BASHRC"; then
  mkdir -p "$(dirname "$BASHRC")"
  cat > "$BASHRC" << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
EOF
fi

# 5. Create hermes wrapper
BIN="$HOME/workspace/.pythonlibs/bin"
mkdir -p "$BIN"
cat > "$BIN/hermes" << 'EOF'
#!/usr/bin/env bash
export HERMES_HOME="$HOME/workspace/.hermes_data"
mkdir -p "$HOME/workspace/.hermes_data"
rm -rf "$HOME/.hermes"
ln -s "$HOME/workspace/.hermes_data" "$HOME/.hermes"
exec "$HOME/hermes-agent/.venv/bin/python" -m hermes_cli.main "$@"
EOF
chmod +x "$BIN/hermes"

# 6. Symlink ephemeral dirs to ~/ (run AFTER venv + pip)
# NOTE: .pythonlibs and .config NOT in loop — Replit auto-manages them
for d in .cache .local; do
  [ -L "$HOME/workspace/$d" ] && continue
  [ -e "$HOME/$d" ] || mkdir -p "$HOME/$d"
  [ -e "$HOME/workspace/$d" ] && mv "$HOME/workspace/$d"/* "$HOME/$d/" 2>/dev/null || true
  rm -rf "$HOME/workspace/$d"
  ln -sf "$HOME/$d" "$HOME/workspace/$d"
done

# 7. Run script.sh and sync.sh (foreground, not background)
bash ~/workspace/script.sh >/dev/null 2>&1
bash ~/workspace/sync.sh

# 8. Launch hermes
$BIN/hermes
```

## Key design decisions

1. **`set -euo pipefail`** — fail fast on errors
2. **Ordering: uv → clone/venv → bashrc → wrapper → symlinks → sync → launch** — symlink loop runs AFTER venv setup so `rm -rf` never destroys `.venv`
3. **No PATH export in script body** — PATH is handled by `~/.config/bashrc` for shells and by Nix default PATH for the script itself
4. **No HERMES_HOME export in script body** — only set in the wrapper, which is where it's needed
5. **`cat >` not `echo >>`** for bashrc — prevents duplicate PATH entries on re-runs
6. **Only `.cache` and `.local` in symlink loop** — `.pythonlibs` and `.config` are managed by Replit's `.replit` config and must stay as real persistent dirs
7. **No curl health check in wrapper** — setup logic belongs in `hermes.sh`, not the per-invocation wrapper
8. **`$BIN/hermes` not bare `hermes`** at launch — explicit path to the wrapper just built
9. **script.sh and sync.sh run foreground** — background (`&`) processes get killed when script exits
10. **`|| true` after `mv`** — handles empty dirs without triggering `set -e`
