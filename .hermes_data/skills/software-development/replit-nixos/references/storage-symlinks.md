# Storage Symlinks: Keeping Workspace Lean

## Problem
Replit's default sets `XDG_CACHE_HOME=/home/runner/workspace/.cache`, making cache persistent in the workspace. Combined with `.local/`, workspace storage balloons to ~1.8 GB+ even though only `.hermes_data/`, `.git/`, and `.pythonlibs/` need to persist.

## Solution
Symlink ephemeral dirs to `~/` (ephemeral) so no path eats workspace storage:

```bash
unset XDG_CACHE_HOME
for d in .cache .local .config; do
  [ -L "$HOME/workspace/$d" ] && continue
  [ -e "$HOME/$d" ] || mkdir -p "$HOME/$d"
  [ -e "$HOME/workspace/$d" ] && mv "$HOME/workspace/$d"/* "$HOME/$d/" 2>/dev/null
  rm -rf "$HOME/workspace/$d" && ln -sf "$HOME/$d" "$HOME/workspace/$d"
done
```

**Do NOT symlink `.pythonlibs`** — it contains pip, python bins, and hermes-agent deps that must persist.

After this: workspace drops to ~600 MB (`.hermes_data` + `.git` + `.pythonlibs` + working files).

**Reverse** (if you ever need cache persistent in workspace instead):
```bash
rm -rf "$HOME/workspace/.cache" && mkdir -p "$HOME/workspace/.cache"
export XDG_CACHE_HOME="$HOME/workspace/.cache"
```

## Key Insight
Both `~/.cache` and `$HOME/workspace/.cache` resolve to the same ephemeral `~/` directory after symlinking. Tools that respect `XDG_CACHE_HOME` AND tools that hardcode `~/.cache` both write ephemeral. No exceptions.

## Post-Reset Recovery
Run `hermes.sh` — it creates the symlinks automatically. No manual setup needed.
