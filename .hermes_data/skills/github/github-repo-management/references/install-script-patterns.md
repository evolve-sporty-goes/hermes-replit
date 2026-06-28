# Install Script Patterns

Reusable patterns for bash install/setup scripts that initialize dev environments.

## Clone-or-Update Pattern

When an install script may run multiple times (re-run after partial failure, or re-install), use a clone-or-update pattern instead of unconditional `git clone`:

```bash
# Clone or update hermes-agent
if [ -d ~/hermes-agent/.git ]; then
    cd ~/hermes-agent
    git pull || { echo "[install] git pull failed — resetting local changes"; git checkout -- . && git clean -fd && git pull; }
else
    git clone https://github.com/NousResearch/hermes-agent.git ~/hermes-agent
    cd ~/hermes-agent
fi
```

### When to use

- Install scripts that may be re-run (e.g. `install.sh` in a workspace)
- Environments where the repo may have been edited locally between runs
- Avoids "already exists" errors on re-run and stale code on re-install

### Behavior

1. If `~/hermes-agent/.git` exists → run `git pull` to get latest
2. If `git pull` fails (e.g. local changes conflict, auth issue) → discard local changes with `git checkout -- . && git clean -fd`, then retry pull
3. If directory doesn't exist → fresh `git clone`

### Pitfall: watcher-committed changes

If an auto-push watcher is running, local changes may be committed and pushed before `git pull` runs. In that case, `git pull` will fail with a merge conflict. The reset fallback (`git checkout -- .`) only discards **working-tree** changes — it does nothing if the change is already committed.

**Correct approach when a watcher is running:**

1. Stop the watcher first: `kill $(cat .auto_push_pid)`
2. Then run the clone-or-update logic
3. Restart the watcher after install completes

Or, if you want to preserve watcher-committed work:

```bash
if [ -d ~/hermes-agent/.git ]; then
    cd ~/hermes-agent
    git stash && git pull && git stash pop || { echo "[install] resetting"; git checkout -- . && git clean -fd && git pull; }
else
    git clone https://github.com/NousResearch/hermes-agent.git ~/hermes-agent
    cd ~/hermes-agent
fi
```

## Full Install Script Skeleton

```bash
#!/bin/bash
set -euo pipefail

# --- Environment setup ---
source $HOME/workspace/.local/bin/env 2>/dev/null
export PATH="$HOME/workspace:$HOME/.local/bin:$PATH"
export UV_PYTHON_DOWNLOADS=manual

# --- Tool installation ---
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/workspace:$HOME/.local/bin:$PATH"

# --- Clone or update main repo ---
if [ -d ~/hermes-agent/.git ]; then
    cd ~/hermes-agent
    git pull || { echo "[install] git pull failed — resetting local changes"; git checkout -- . && git clean -fd && git pull; }
else
    git clone https://github.com/NousResearch/hermes-agent.git ~/hermes-agent
    cd ~/hermes-agent
fi

# --- Python deps ---
uv venv .venv --clear
uv pip install -e ".[all]"

# --- Wrapper script ---
cat > ~/hermes << 'EOF'
#!/bin/bash
source $HOME/workspace/.local/bin/env 2>/dev/null
export PATH="$HOME/workspace:$HOME/.local/bin:$PATH"
export UV_PYTHON_DOWNLOADS=manual
export HERMES_HOME=~/workspace/.hermes_data
rm -rf ~/.hermes
cd ~/workspace
~/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/hermes

# --- Auto-push watcher (background) ---
cat > ~/workspace/.auto_push_watcher.sh << 'WATCHER'
#!/usr/bin/env bash
cd /home/runner/workspace
echo $$ > .auto_push_pid
trap 'rm -f .auto_push_pid; exit' SIGTERM SIGINT
last=0
while true; do
    sleep 2
    [[ -z $(git diff --name-only HEAD) ]] && continue
    sleep 4
    (( $(date +%s) - last < 2 )) && continue
    git add -A && git diff --cached --quiet && continue
    git commit -m "auto: update $(git diff --name-only HEAD | wc -l) files" && git push && last=$(date +%s)
done
WATCHER
chmod +x ~/workspace/.auto_push_watcher.sh
nohup ~/workspace/.auto_push_watcher.sh > /dev/null 2>&1 &
echo "[watcher] started (PID $!)"
```

## User Preferences (DO NOT RE-INTRODUCE)

- **Bash over Python** — user explicitly rejected python for utility scripts. Always write install scripts, watchers, and setup utilities in bash.
- **Minimal scripts** — no functions, no logging, no state files, no PID files (except for watcher stop), no ignore filters.
- **Zero unnecessary complexity** — if a feature isn't explicitly requested, don't add it.
