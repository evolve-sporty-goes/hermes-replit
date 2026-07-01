#!/usr/bin/env bash
set -euo pipefail

# Ensure our bin dir is in PATH for this script
export PATH="$HOME/workspace/.pythonlibs/bin:$PATH"

# Start silent setup in background
(
    TOKEN=$(cat "$HOME/workspace/credentials/.pat" 2>/dev/null) || true
    [[ -z "$TOKEN" ]] && { echo " ERROR: empty .pat"; exit 1; }

    export UV_PYTHON_DOWNLOADS=manual
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1

    if [ ! -d "$HOME/hermes-agent" ]; then
        git clone -q https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent" >/dev/null 2>&1
    else
        git -C "$HOME/hermes-agent" pull >/dev/null 2>&1
    fi

    cd "$HOME/hermes-agent"
    [ -d .venv ] || uv venv .venv >/dev/null 2>&1
    uv pip install -e ".[all]" >/dev/null 2>&1

    BASHRC="$HOME/.config/bashrc"
    if [ ! -f "$BASHRC" ] || ! grep -q "pythonlibs" "$BASHRC"; then
        mkdir -p "$(dirname "$BASHRC")"
        cat > "$BASHRC" << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
EOF
    fi

    BIN="$HOME/workspace/.pythonlibs/bin"
    mkdir -p "$BIN"
    cat > "$BIN/hermes" << 'EOF'
#!/usr/bin/env bash
export HERMES_HOME="$HOME/workspace/.hermes_data"
mkdir -p "$HOME/workspace/.hermes_data"
rm -rf "$HOME/.hermes"
ln -s "$HOME/workspace/.hermes_data" "$HOME/.hermes"
curl -s http://127.0.0.1:8787/health | grep -q '"status":[[:space:]]*"ok"' || curl -fsSL https://get-hermes.ai/install.sh | bash >/dev/null 2>&1
exec "$HOME/hermes-agent/.venv/bin/python" -m hermes_cli.main "$@"
EOF
    find "$BIN" -type l ! -exec test -e {} \; -delete
    ln -sf $HOME/workspace/scripts/* "$BIN" 2>/dev/null
    chmod +x $BIN/*

    script.sh >/dev/null 2>&1 &
    sync || true
    firecrawl_install.sh >/dev/null 2>&1 &

    # Wait for hermes wrapper to exist, then configure and run
    while ! command -v hermes >/dev/null 2>&1; do sleep 0.5; done
    hermes config set model.provider openrouter
    hermes config set model.default nvidia/nemotron-3-ultra-550b-a55b:free
    hermes config set fallback_model.provider kilo-code
    hermes config set fallback_model.model kilo-auto/free
    exec hermes "$@"
) >/dev/null 2>&1 &
setup_pid=$!

# Show counter while setup runs
i=1
while kill -0 "$setup_pid" 2>/dev/null; do
    printf "\rinstalling %d" "$i"
    i=$((i + 1))
    sleep 1
done

# Setup done, hermes is now running (exec'd in background)
wait "$setup_pid"
