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
#!/bin/bash
export PATH="$P" UV_PYTHON_DOWNLOADS=manual HERMES_HOME=~/workspace/.hermes_data
rm -rf ~/.hermes && cd ~/workspace
$V/python -m hermes_cli.main "\$@"
EOF
chmod +x ~/hermes
[ -d "$HOME/hermes-agent/hermes-webui" ] || git clone https://github.com/nesquena/hermes-webui.git "$HOME/hermes-agent/hermes-webui"
nohup $V/python "$HOME/hermes-agent/hermes-webui/server.py" >/tmp/hermes-webui.log 2>&1 &
bash script.sh >/dev/null 2>&1 &
bash ~/workspace/sync.sh && ~/hermes
