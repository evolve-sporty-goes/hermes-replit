# Bash Watchdog Resilience Patterns

Patterns for long-running bash watcher loops (auto-commit/push, file sync, health checks, etc.) that stay correct across partial failures.

## The Short-Circuit Cooldown Pattern

The most common bug: a `&&` chain that updates the cooldown timestamp only on success, but a silent failure leaves the timestamp stale and the loop never retries.

### Anti-pattern (cooldown updated unconditionally)

```bash
git add -A && git diff --cached --quiet && continue
git commit -m "auto: update N files" && git push && last=$(date +%s)
# If push fails, `last` still advances → next tick blocked by cooldown.
```

### Correct pattern

```bash
if git commit -m "auto: update N files"; then
    git push && last=$(date +%s)
fi
# Push failure leaves `last` unchanged → next tick retries without waiting.
```

General rule: **the operation that mutates external state (push, deploy, publish) is the operation that gates the cooldown update**. Never advance the timestamp on a partial success.

## Verification

After editing a watcher loop, verify the failure path does not advance the timestamp:

1. Source the loop body with stubbed functions.
2. Assert: after one iteration where push fails, `last` is still its initial value.

```bash
file=$(mktemp /tmp/hermes-verify-watchdog.XXXXXX.sh)
cat > "$file" << 'SCRIPT'
set -u
last=0; push() { return 1; } ; commit() { return 0; }
git add -A && git diff --cached --quiet && exit 0
if commit -m "auto"; then push && last=$(( $(date +%s) - 1 )); fi
[[ "$last" -eq 0 ]] && echo "PASS: cooldown not advanced on push fail" || { echo "FAIL"; exit 1; }
SCRIPT
bash "$file"; rm -f "$file"
```

Note: the Hermes runtime may block ad-hoc verification scripts under `/tmp` — treat this as a static-check complement, not a substitute for `bash -n` syntax validation.

## Other Rules for Watcher Loops

1. **Trap SIGTERM/SIGINT** and remove the PID file on exit.
   ```bash
   trap 'rm -f .watcher_pid; exit' SIGTERM SIGINT
   ```
2. **Write PID to a file** so external processes can stop it cleanly.
3. **Debounce (sleep-then-sleep)** between tick and commit — lets file saves settle so you don't commit mid-write.
4. **Never `continue` past the mutation step** without committing — otherwise you loop on the same dirty state.
5. **Commit before push inside the `if`** — if commit fails you must not push; if push fails you keep the commit (so the next tick can retry).
6. **Prefer `git diff --cached --quiet` over `git diff --cached`** — the quiet variant gives only exit status, less noise.
7. **`nohup` the launch** and redirect to `/dev/null` so the watcher survives the parent shell.

## Example: Auto-commit/push watcher (resilient)

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
    if git commit -m "auto: update $(git diff --name-only HEAD | wc -l) files"; then
        git push && last=$(date +%s)
    fi
done
```

## When to Use Watchers vs Cron

| Criterion | Watcher | Cron |
|-----------|---------|------|
| Latency | Near-immediate (2–6s delay) | Minutes (schedule-dependent) |
| Reliability | Dies with parent shell | Survives restarts |
| Retries | Manual logic needed | Configurable via `context_from` |
| Interaction with agent | Complementary (agent sets up, watcher runs) | Standalone |

For auto-commit/push during pairing sessions: if latency matters, use the watcher. If you need guaranteed delivery regardless of terminal lifetime, use a Hermes cron job with `hermes cron create`.

## Commit message convention for auto-watchers

Use the format `auto: update N files` where N is the count of changed files. This keeps commit messages informative without manual effort. **Always commit ALL files** including data directories (`.hermes_data/`, state files, logs) — do not use `.gitignore` filters in the watcher itself; rely on a project `.gitignore` if needed.
