# Symlink vs Hard Link Decision Guide

## Quick Reference

| Criteria | `ln -s` (symlink) | `ln` (hard link) |
|----------|-------------------|-----------------|
| Cross-filesystem | ✅ Yes | ❌ No |
| Link directories | ✅ Yes | ❌ No |
| Survives original delete | ❌ Becomes dangling | ✅ Data persists |
| Same inode as original | ❌ No | ✅ Yes |
| `ls -l` shows target | ✅ Yes (transparent) | ❌ No (looks real) |
| Force overwrite | `ln -sf` | `ln -f` |

## Replit-Specific Notes

On Replit NixOS, `/home/runner/workspace/` is a persistent mount. `$HOME/workspace/.pythonlibs/bin/` is typically on the same filesystem, so hard links work. But symlinks are more conventional and safer for automation.

## When to Use Each

### Use symlinks when:
- Linking into PATH directories
- You want to see what's a link vs real file (`ls -la`)
- Source and dest might be on different mounts
- You need to link directories (e.g., `ln -s scripts/ bin/scripts/`)

### Use hard links when:
- You explicitly don't want directories linked (hard link rejects dirs)
- You want the link to survive source deletion
- Same-filesystem guarantee exists
- You want identical inode (backup tools, deduplication)

## Common Errors

### "File exists" when creating symlink
Fix: `ln -sf` (force overwrites existing link/file)

### "Invalid cross-device link" when creating hard link
Fix: Use symlink instead, or ensure source and dest are on same filesystem

### Dangling symlinks after source deletion
Detect: `find /path -type l ! -exec test -e {} \; -print`
Remove: `find /path -type l ! -exec test -e {} \; -delete`
Fix: `ln -sf /new/target /path/to/dangling-link`

## inotifywait for Auto-chmod

When using symlinks + needing new files to be executable:

```bash
# Add to hermes.sh or run as background process:
inotifywait -m -e create -e moved_to --format '%w%f' \
  $HOME/workspace/scripts/ | while read f; do chmod +x "$f"; done &
```

**How it works:** Linux kernel inotify subsystem watches the directory for filesystem events. Zero CPU when idle. Triggers only on file creation or move-into events.

**Debounce pattern** (for sync scripts to avoid rapid-fire):
```bash
inotifywait -m -e modify -e create --format '%w%f' /path/to/watch | \
  while read f; do sleep 2; done  # wait 2s after last event
```
