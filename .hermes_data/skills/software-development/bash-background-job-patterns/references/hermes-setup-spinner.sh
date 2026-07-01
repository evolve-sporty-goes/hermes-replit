#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/workspace/.pythonlibs/bin:$PATH"

LOGFILE="$HOME/workspace/.hermes_data/setup.log"
mkdir -p "$(dirname "$LOGFILE")"

(
    TOKEN=$(cat "$HOME/workspace/credentials/.pat" 2>/dev/null) || true
    [[ -z "$TOKEN" ]] && exit 1

    export UV_PYTHON_DOWNLOADS=manual
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
    [ -d "$HOME/hermes-agent" ] || git clone -q https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent"
    cd "$HOME/hermes-agent"
    [ -d .venv ] || uv venv .venv
    uv pip install -e ".[all]"
    BIN="$HOME/workspace/.pythonlibs/bin"; mkdir -p "$BIN"
    cat > "$BIN/hermes" << 'EOF'
#!/usr/bin/env bash
export HERMES_HOME="$HOME/workspace/.hermes_data"
mkdir -p "$HOME/workspace/.hermes_data"
rm -rf "$HOME/.hermes"
ln -s "$HOME/workspace/.hermes_data" "$HOME/.hermes"
curl -s http://127.0.0.1:8787/health | grep -q '"status":[[:space:]]*"ok"' || curl -fsSL https://get-hermes.ai/install.sh | bash >/dev/null 2>&1
hermes "$@"
EOF
    chmod +x "$BIN/hermes"
    while ! command -v hermes >/dev/null 2>&1; do sleep 0.5; done
    hermes config set model.provider openrouter
    hermes config set model.default nvidia/nemotron-3-ultra-550b-a55b:free
    hermes config set fallback_model.provider kilo-code
    hermes config set fallback_model.model kilo-auto/free
    hermes
) >>"$LOGFILE" 2>&1 &
pid=$!

spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
i=0
while kill -0 "$pid" 2>/dev/null; do
    printf "\r${spinner[i%10]}"
    i=$((i+1))
    sleep 0.1
done
wait "$pid"