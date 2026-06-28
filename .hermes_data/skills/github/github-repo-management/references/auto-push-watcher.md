# Auto-Push File Watcher

Watches workspace for file changes → `git add -A` → commit → `git push` (via SSH). Runs continuously in the background.

## Usage

```bash
# Start in background
bash .auto-push-watcher.sh &

# Stop
kill $(cat .auto_push_pid)
```

## Script (canonical — 12 lines, no functions, no logging)

```bash
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
    changed=$(git diff --name-only HEAD --cached)
    summary=$(echo "$changed" | head -3 | tr '\n' ', ' | sed 's/,$//')
    [ $(echo "$changed" | wc -l) -gt 3 ] && summary="$summary ..."
    git commit -m "chore: update $summary" && git push && last=$(date +%s)
done
```

## Design

- **2s poll interval** — fast detection
- **4s debounce** — wait for writes to settle before committing
- **2s push throttle** — prevent rapid-fire pushes
- **No ignore filters in script** — `.gitignore` handles exclusions. Do NOT add IGNORE/SELF regex filters.
- **PID file**: `kill $(cat .auto_push_pid)` to stop
- **Detection**: `git diff --name-only HEAD` — git-native, respects `.gitignore`, handles renames
- **No logging** — stdout goes to `/dev/null` when launched via nohup. Add `>> .push_log` only if debugging.

## Commit messages

- Always descriptive, derived from actual changed files. Format: `chore: update <file1>, <file2>, <file3> ...`
- Never use generic `auto: update N files` — the user explicitly rejected this pattern.
- Build the summary from `git diff --name-only HEAD --cached`, take first 3 filenames, comma-separated.
- If more than 3 files changed, append ` ...` after the third name.

## Embed in install/setup scripts

When writing an install script that initializes a dev environment, embed the watcher inline and launch with `nohup`:

```bash
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
```

## Pitfall: "revert" doesn't undo watcher-committed changes

When the auto-push watcher is active, `git add` + `commit` + `push` may happen within seconds of a file edit. If the user says "revert this change" or "undo that edit", the naive approach (`git checkout -- <file>`) only discards **working-tree** changes — it does nothing if the change is already committed and pushed.

**Correct revert procedure when a watcher is running:**

1. Check if the change is already committed: `git log --oneline -5 -- <file>`
2. If committed: `git revert HEAD` (creates a new revert commit) or `git reset --soft HEAD~1` (uncommits, keeps changes staged) then rework
3. If not yet committed: `git checkout -- <file>` works fine
4. If already pushed: `git revert HEAD` is the safe path (don't rewrite shared history)

**Never** assume `git checkout -- <file>` is sufficient — always check `git diff HEAD -- <file>` and `git log -1 -- <file>` first to know what state you're dealing with.

## Iteration history (user preferences — DO NOT RE-INTRODUCE)

1. Started python, ~165 lines with mtime-walk + double-debounce + IGNORE + SELF + STATE_FILE
2. User requested: "use bash instead of python"
3. User requested: "make it short and simple"
4. User requested: "remove unnecessary files" (old .py, .push_log, stale .pid)
5. User requested: "dont set ignore or something in script" — remove all IGNORE/SELF filters, commit everything, rely on .gitignore
6. User requested: "make it too short" — inline flat loop, no functions, no logging

**Lesson**: user wants the script to be a pure detect→commit→push loop with zero business logic about what to exclude. Exclusions belong in `.gitignore`. Do not add helper functions, logging, or ignore filters back.
