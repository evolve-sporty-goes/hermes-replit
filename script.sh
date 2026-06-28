#!/bin/bash
export DISPLAY=:1 VNC_PORT=5901 NOVNC_PORT=5000

# Install dependencies on Debian-based systems (non-Replit)
command -v apt >/dev/null 2>&1 && sudo apt install -y xterm tigervnc-standalone-server xvfb fluxbox

# Clean up any stale X lock files
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Start TigerVNC server
Xvnc :1 -geometry 2560x1440 -depth 24 -rfbport $VNC_PORT -SecurityTypes None -AlwaysShared &>/dev/null &

sleep 1

# Set up fluxbox window manager
mkdir -p $HOME/.fluxbox
echo "session.menuFile: $HOME/.fluxbox/menu" > $HOME/.fluxbox/init
echo -e "#!/bin/bash\nfluxbox" > $HOME/.fluxbox/startup && chmod +x $HOME/.fluxbox/startup
echo -e "[begin] (Fluxbox)\n   [exec] (Run Script) {xterm -e bash -c 'bash email.sh; exec bash'; xterm }\n[end]" > $HOME/.fluxbox/menu

# Clone noVNC if not present
if [ ! -d "$HOME/noVNC" ]; then
    git clone -q https://github.com/novnc/noVNC.git "$HOME/noVNC"
    git clone -q https://github.com/novnc/websockify.git "$HOME/noVNC/utils/websockify"
fi
ln -sf "$HOME/noVNC/vnc.html" "$HOME/noVNC/index.html"

# Start noVNC proxy
cd ~/noVNC && ./utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT &

# Start fluxbox desktop
DISPLAY=:1 $HOME/.fluxbox/startup &

# On non-Replit environments, create a cloudflared tunnel for external access
if [ -z "$REPL_ID" ]; then
    echo "[Tunnel] Not running on Replit — starting cloudflared tunnel..."
    curl -sLO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x ./cloudflared-linux-amd64
    ./cloudflared-linux-amd64 tunnel --url localhost:$NOVNC_PORT 2>&1 | grep -o 'https://[^ ]*trycloudflare.com' | head -1 &
else
    echo "[Info] Running on Replit — access via the built-in preview pane."
fi

# Keep the process alive
while :; do sleep 5; echo "."; done
