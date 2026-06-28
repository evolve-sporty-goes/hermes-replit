# hermes.sh Bootstrap Reference

The workspace uses a single `hermes.sh` (formerly `install.sh`) at repo root as the Replit entrypoint. This is the current canonical version (2026-06, 21 lines):

```bash
#!/bin/bash
set -euo pipefail
source $HOME/workspace/.local/bin/env 2>/dev/null
P="$HOME/workspace:$HOME/.local/bin"
export PATH="$P" UV_PYTHON_DOWNLOADS=manual HERMES_HOME=~/workspace/.hermes_data
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/NousResearch/hermes-agent.git ~/hermes-agent
cd ~/hermes-agent
uv venv .venv --clear && uv pip install -e ".[all]"
V="$HOME/hermes-agent/.venv/bin"
cat > ~/hermes << EOF
#!/usr/bin/env bash
export PATH="$P" UV_PYTHON_DOWNLOADS=manual HERMES_HOME=~/workspace/.hermes_data
rm -rf ~/.hermes && cd ~/workspace
$V/python -m hermes_cli.main "\$@"
EOF
chmod +x ~/hermes
[ -d "$HOME/hermes-agent/hermes-webui" ] || git clone https://github.com/nesquena/hermes-webui.git "$HOME/hermes-agent/hermes-webui"
nohup $V/python "$HOME/hermes-agent/hermes-webui/server.py" >/tmp/hermes-webui.log 2>&1 &
bash script.sh >/dev/null 2>&1 &
bash ~/workspace/sync.sh && ~/hermes
```

## Style rules (hard requirements)

The user explicitly requires scripts be **short and crisp**. These are non-negotiable:

| Rule | Example | Anti-pattern |
|------|---------|--------------|
| Merge export lines | `export PATH="..." UV_PYTHON_DOWNLOADS=manual HERMES_HOME=...` | Separate `export` per var |
| Short-circuit guards | `[ -d dir ] || git clone ...` | `if [ ! -d ]; then ... fi` |
| Inline `&&` chains | `uv venv ... && uv pip install ...` | Two separate statements |
| Full path over `cd` | `"$HOME/hermes-agent/hermes-webui/server.py"` | `cd dir && server.py` |
| Drop comments & blank lines | (none in body) | Section headers, blank separators |
| Variable dedup | `V="$HOME/hermes-agent/.venv/bin"` then `$V/python` | Repeat full path 3x |
| `set -euo pipefail` | line 2 | (none — always include) |

**Target: under 30 lines.** Current: 21 lines.

## Key design decisions

1. **`set -euo pipefail`** — fail fast on errors, undefined vars, or pipe failures.
2. **`UV_PYTHON_DOWNLOADS=manual`** — prevents uv from auto-downloading Python (Nix ships its own).
3. **`HERMES_HOME=~/workspace/.hermes_data`** — agent state in persistent workspace, not `~`.
4. **`rm -rf ~/.hermes`** in wrapper — re-resolves to workspace profile each invocation.
5. **hermes-webui is a separate git repo** (`nesquena/hermes-webui`), not a submodule. Clone is idempotent via `[ -d ... ] ||`.
6. **WebUI launched directly** with `nohup $V/python server.py` — logs to `/tmp/hermes-webui.log`. No `ctl.sh` intermediate.
7. **`bash sync.sh && ~/hermes`** — sync secrets then launch CLI in one chain.

## Execution order

1. Activate local env (uv from prior install)
2. Install uv (if not present)
3. Clone hermes-agent → venv → install
4. Create `~/hermes` wrapper (uses `$P` and `$V` for brevity)
5. Clone + start hermes-webui (background, nohup)
6. Run `script.sh` (background desktop/services)
7. Sync secrets + launch hermes CLI

## Verification

```bash
bash -n hermes.sh                    # syntax check
hermes --version                      # works if on PATH
```

## Making `hermes` available in fresh shells — THE WRONG WAY

A **symlink** into `~/.local/bin` does NOT work — the symlink target (`venv/bin/hermes`) is a script that depends on venv dependencies but the venv isn't activated in a fresh shell:

```bash
# WRONG — breaks in fresh shell because venv deps aren't loadable:
ln -sf $(which hermes) ~/.local/bin/hermes
```

## Making `hermes` available in fresh shells — THE RIGHT WAY

Create a **wrapper script** that invokes the venv Python directly:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/hermes << 'EOF'
#!/bin/bash
exec /home/runner/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/.local/bin/hermes
```

After this, `hermes` (bare command) works in any fresh terminal because `.local/bin` is on Replit's default PATH. No venv activation needed — the Python binary has its deps baked in.

> **Pattern note:** When a tool lives in a venv binary, the fix for "command not found in fresh shell" is a wrapper script pointing at the venv's Python directly — NOT a symlink to the venv's wrapper script (which depends on PATH entries the fresh shell doesn't have).
