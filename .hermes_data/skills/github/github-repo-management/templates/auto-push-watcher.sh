#!/usr/bin/env bash
# Watch workspace → auto-commit → push. Runs in background: kill $(cat .auto_push_pid)
# Usage: bash auto-push-watcher.sh &   |   kill $(cat .auto_push_pid)
#
# Pure detect→commit→push loop. No ignore filters (use .gitignore).
# No logging, no state files, no functions. ~12 lines.
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
