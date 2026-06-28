# Ephemeral Symlink Pattern

Keep ephemeral data out of workspace by symlinking to `~/`.

## Problem
Replit's `XDG_CACHE_HOME` defaults to `$HOME/workspace/.cache` — persistent storage. Tools write cache into workspace, inflating it (1.2 GB+ observed). On reset, all ephemeral dirs are wiped anyway, so keeping them in workspace wastes space for no benefit.

## Solution
Symlink each ephemeral dir to `~/` so both the bare name and the workspace name resolve to the same ephemeral location:

```bash
unset XDG_CACHE_HOME
for d in .cache .local .config; do
  [ -L "$HOME/workspace/$d" ] && continue  # idempotent
  [ -e "$HOME/$d" ] || mkdir -p "$HOME/$d"
  [ -e "$HOME/workspace/$d" ] && mv "$HOME/workspace/$d"/* "$HOME/$d/" 2>/dev/null  # migrate
  rm -rf "$HOME/workspace/$d" && ln -sf "$HOME/$d" "$HOME/workspace/$d"
done
```

**CRITICAL: `.pythonlibs` is NOT in this loop.** It contains pip, python binaries, and hermes-agent deps that must persist across resets. Keep it as a real directory in workspace.

## Result

Before:
```
Workspace: 1.8 GB
  .cache      1.2 GB  (persistent, wasted)
  .pythonlibs 310 MB (persistent, needed)
  .local       75 MB (persistent, wasted)
  .config      27 MB (persistent, wasted)
  .hermes_data 172 MB
  .git         61 MB
```

After:
```
Workspace: ~600 MB
  .cache      → symlink to ~/.cache (ephemeral)
  .pythonlibs  310 MB (persistent, real dir)
  .local      → symlink to ~/.local (ephemeral)
  .config     → symlink to ~/.config (ephemeral)
  .hermes_data 172 MB (persistent)
  .git         61 MB (persistent)
```

## Invocation in setup script (`hermes.sh`)

Add after env exports:
```bash
# Keep ephemeral data out of workspace via symlinks
unset XDG_CACHE_HOME
for d in .cache .local .config; do
  [ -L "$HOME/workspace/$d" ] && continue
  [ -e "$HOME/$d" ] || mkdir -p "$HOME/$d"
  [ -e "$HOME/workspace/$d" ] && mv "$HOME/workspace/$d"/* "$HOME/$d/" 2>/dev/null
  rm -rf "$HOME/workspace/$d" && ln -sf "$HOME/$d" "$HOME/workspace/$d"
done
```

## Verification

```bash
ls -la ~/workspace/.cache ~/workspace/.local ~/workspace/.config
# All should be symlinks → ~/

ls -la ~/workspace/.pythonlibs
# Should be a REAL directory (not symlink)

du -sh ~/workspace/
# Should be ~600 MB
```
