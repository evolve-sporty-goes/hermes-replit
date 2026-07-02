#!/usr/bin/env bash
cd ~/workspace
export DISPLAY=:1
export PYTHONUNBUFFERED=1
LOG=~/workspace/logs/cloudflare_signup.log
mkdir -p ~/workspace/logs
python3 ~/workspace/scripts/cloudflare_signup.py "$@" 2>&1 | tee "$LOG"
