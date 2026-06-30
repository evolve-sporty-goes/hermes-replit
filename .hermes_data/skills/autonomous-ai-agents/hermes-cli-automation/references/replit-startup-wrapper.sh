#!/usr/bin/env bash
# Replit Hermes startup wrapper with auto-restart on failure
# Place at: scripts/hermes-startup.sh
set -uo pipefail

MAX_RESTARTS=10
RESTART_WINDOW=300  # seconds
RESTART_DELAY=5
LOGFILE="$HOME/workspace/logs/hermes-startup.log"
PIDFILE="/tmp/hermes-startup.pid"

mkdir -p "$(dirname "$LOGFILE")"

# Prevent multiple instances
if [[ -f "$PIDFILE" ]]; then
    OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[$(date)] Already running (PID $OLD_PID). Exiting." >> "$LOGFILE"
        exit 0
    fi
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"; tail -1000 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"; }

restart_timestamps=()

count_recent_restarts() {
    local now=$(date +%s)
    local cutoff=$((now - RESTART_WINDOW))
    local count=0
    for ts in "${restart_timestamps[@]}"; do
        (( ts > cutoff )) && ((count++))
    done
    echo "$count"
}

record_restart() {
    restart_timestamps+=("$(date +%s)")
}

log "=== Hermes startup wrapper (PID $$) ==="

# Phase 1: Install uv
if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >> "$LOGFILE" 2>&1
    export PATH="$HOME/.local/bin:$HOME/workspace/.pythonlibs/bin:$PATH"
fi

# Phase 2: Clone or update hermes-agent
if [[ ! -d "$HOME/hermes-agent" ]]; then
    git clone https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent" >> "$LOGFILE" 2>&1
else
    git -C "$HOME/hermes-agent" pull >> "$LOGFILE" 2>&1 || log "WARN: git pull failed"
fi

# Phase 3: Create venv + install deps
(
    cd "$HOME/hermes-agent"
    [[ -d .venv ]] || uv venv .venv >> "$LOGFILE" 2>&1
    uv pip install -e ".[all]" >> "$LOGFILE" 2>&1
) || log "WARN: venv install had issues"

# Phase 4: PATH setup
export PATH="$HOME/.local/bin:$HOME/workspace/.pythonlibs/bin:$PATH"
BASHRC="$HOME/.config/bashrc"
if [[ ! -f "$BASHRC" ]] || ! grep -q "pythonlibs" "$BASHRC"; then
    mkdir -p "$(dirname "$BASHRC")"
    cat > "$BASHRC" << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
EOF
fi

# Phase 5: Create hermes wrapper
BIN="$HOME/workspace/.pythonlibs/bin"
mkdir -p "$BIN"
cat > "$BIN/hermes" << 'HERMES_WRAPPER'
#!/usr/bin/env bash
export HERMES_HOME="$HOME/workspace/.hermes_data"
mkdir -p "$HOME/workspace/.hermes_data"
rm -rf "$HOME/.hermes"
ln -s "$HOME/workspace/.hermes_data" "$HOME/.hermes"
exec "$HOME/hermes-agent/.venv/bin/python" -m hermes_cli.main "$@"
HERMES_WRAPPER
chmod +x "$BIN/hermes"
ln -sf $HOME/workspace/scripts/* "$BIN" 2>/dev/null
find "$BIN" -type l ! -exec test -e {} \; -delete 2>/dev/null
chmod +x "$BIN"/* 2>/dev/null || true

# Phase 6: Background services (start once)
if ! pgrep -f "script.sh" >/dev/null 2>&1; then
    bash "$HOME/workspace/scripts/script.sh" >> "$LOGFILE" 2>&1 &
    log "Started background services (PID $!)"
fi

# Phase 7: Launch hermes with auto-restart
log "Phase 7: Launching hermes (auto-restart enabled)..."
while true; do
    recent=$(count_recent_restarts)
    if (( recent >= MAX_RESTARTS )); then
        log "FATAL: $MAX_RESTARTS restarts within ${RESTART_WINDOW}s. Stopping."
        exit 1
    fi

    record_restart
    log "Starting hermes (restart #$((${#restart_timestamps[@]})) in window)..."

    hermes update >> "$LOGFILE" 2>&1 || log "WARN: hermes update failed"
    hermes >> "$LOGFILE" 2>&1
    EXIT_CODE=$?

    log "hermes exited with code $EXIT_CODE"
    if [[ $EXIT_CODE -eq 0 ]]; then
        log "Clean exit. Stopping wrapper."
        exit 0
    fi

    log "Restarting in ${RESTART_DELAY}s..."
    sleep "$RESTART_DELAY"
done
