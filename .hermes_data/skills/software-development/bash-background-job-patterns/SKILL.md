---
name: bash-background-job-patterns
description: Reusable bash patterns for running silent background setup with a foreground spinner/progress indicator.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [bash, background-jobs, spinner, progress-indicator, silent-setup]
    category: software-development
    related_skills: [script-validation-and-execution, workspace-organization]
    config: {}
---

# Bash Background Job Patterns

Recurring pattern: run a long silent setup in background, show a spinner on a single line until it finishes, then hand off to the spawned process.

## Core Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

# Start silent background job
(
    # All setup commands here, output redirected to /dev/null
    command1 >/dev/null 2>&1
    command2 >/dev/null 2>&1
    # ... eventually exec the target process
    exec target_command "$@"
) >/dev/null 2>&1 &
pid=$!

# Spinner loop
spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
i=0
while kill -0 "$pid" 2>/dev/null; do
    printf "\r${spinner[i%10]}"
    i=$((i+1))
    sleep 0.1
done

# Background job has either exited or exec'd into target
wait "$pid"
```

## Key Points

- Subshell `( ... ) &` runs silently when stdout/stderr redirected
- `exec target_command` replaces the subshell PID — `kill -0 $pid` then fails, stopping the spinner
- `wait $pid` reaps the process and propagates its exit code
- Spinner updates every 100ms (10 frames) on a single line via `\r`

## Variations

### Counter instead of spinner
```bash
i=1
while kill -0 "$pid" 2>/dev/null; do
    printf "\rinstalling %d" "$i"
    i=$((i+1))
    sleep 1
done
```

### With custom message
```bash
printf "\r${spinner[i%10]} Setting up..."
```

## Applied In This Session

Created `workspace/scripts/hermes.sh` using this pattern:
- Silent setup: uv install, git clone, venv, pip install, wrapper creation, hermes config
- Spinner runs until `exec hermes` replaces the subshell
- Script waits for hermes to exit

## References

- `references/hermes-setup-spinner.sh` — the concrete script from this session