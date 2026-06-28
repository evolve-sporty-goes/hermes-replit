#!/usr/bin/env bash
# Auto-commit/push watcher for a git pairing workspace.
#
# Trigger: agent session pairing with a human who wants every change pushed.
# Design notes:
#   - Reactive (polls every 2s, debounces 4s before committing).
#   - Cooldown timestamp `last` advances ONLY on push success, so a failed
#     push does not suppress the next retry.
#   - SIGTERM/SIGINT clean up the PID file so no orphaned loop persists.
#   - PID written to .auto_push_pid so any external process can stop it:
#       kill $(cat .auto_push_pid) 2>/dev/null
#   - Launched with nohup from install.sh; change the path/port below if
#     your workspace root differs.

set -u
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
    if git commit -m "auto: update $(git diff --name-only HEAD | wc -l) files"; then
        git push && last=$(date +%s)
    fi
done
