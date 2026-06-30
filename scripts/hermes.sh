#!/usr/bin/env bash
set -euo pipefail


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
export PATH
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
curl -s http://127.0.0.1:8787/health | grep -q '"status":[[:space:]]*"ok"' || curl -fsSL https://get-hermes.ai/install.sh | bash >/dev/null 2>&1 ##for hermes-webgui do not remove
exec "$HOME/hermes-agent/.venv/bin/python" -m hermes_cli.main "$@"
EOF
find "$BIN" -type l ! -exec test -e {} \; -delete
ln -sf $HOME/workspace/scripts/* "$BIN" 2>/dev/null
chmod +x $BIN/*

script.sh >/dev/null 2>&1 &
sync 
setcfapi.sh
firecrawl_install.sh &
# 8. Launch hermes
hermes update
hermes
