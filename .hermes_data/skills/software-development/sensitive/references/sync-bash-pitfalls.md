# Bash Pitfalls in Sync Scripts

Pitfalls discovered while rewriting `scripts/sync` (v3, 2026-06-29). These apply to any long-running bash script that does git operations.

## 1. `set -e` + `while read` EOF

**Symptom:** Script exits 1 after the `while` loop completes, even though all iterations succeeded.

**Cause:** `read` returns exit code 1 at EOF. With `set -e`, this terminates the script.

**Fix:** Use `set -uo pipefail` (drop `-e`). Handle errors explicitly with `||`.

```bash
# BAD — dies at EOF
set -euo pipefail
while IFS= read -r line; do
  process "$line"
done <<< "$data"

# GOOD — survives EOF
set -uo pipefail
while IFS= read -r line; do
  process "$line" || true
done <<< "$data"
```

## 2. Function Definition Order

**Symptom:** `command not found` for a function that's clearly defined in the script.

**Cause:** Bash parses top-to-bottom. Functions must be defined BEFORE they're called.

```bash
# BAD
while IFS= read -r f; do
  _sync_one "$f"          # ERROR: _sync_one not yet defined
done <<< "$files"

_sync_one() { echo "$1"; }

# GOOD
_sync_one() { echo "$1"; }

while IFS= read -r f; do
  _sync_one "$f"          # OK
done <<< "$files"
```

## 3. Trap RETURN from Functions

**Symptom:** Resource cleaned up while still needed by caller.

**Cause:** `trap "cleanup" RETURN` inside a function fires when the function returns.

```bash
# BAD — askpass deleted before Phase 2 uses it
phase1() {
  ASKPASS=$(mkfile)
  trap 'rm -f "$ASKPASS"' RETURN
  # ... use askpass ...
}
phase1
# ASKPASS is gone here
git push  # FAILS: no auth

# GOOD — single EXIT trap at script scope
ASKPASS=$(mkfile)
trap 'rm -f "$ASKPASS"' EXIT
phase1
git push  # OK: askpass still exists
```

## 4. Subshell Flag Setting

**Symptom:** Flag variable stays 0 even when function signals change.

**Cause:** `func && s=$? || s=$?` is fragile — if `func` returns 1, the `||` branch runs but `s` may be overwritten.

```bash
# BAD
_sync_one "$f" && s=$? || s=$?
[ "$s" -eq 1 ] && changed=1

# GOOD
_sync_one "$f" || changed=1
```

## 5. Askpass Lifecycle Across Phases

**Symptom:** `fatal: cannot exec '/tmp/tmp.XXX/git-askpass': No such file or directory`

**Cause:** Phase 1's cleanup trap fires before Phase 2's push. The askpass file is deleted while Phase 2 still needs it.

**Fix:** Create askpass once at script scope. Clean up in EXIT trap (fires only when the whole script exits).

## 6. `find ... -print0` with Empty Results

**Symptom:** Loop body never executes, but that's actually correct behavior.

**Note:** `find` with no matches exits 0. The `while read -r -d ''` loop simply doesn't run. This is safe — don't add `|| true` to `find` here because it would mask real errors.

```bash
# This is FINE — loop just won't run if no files
while IFS= read -r -d '' f; do
  process "$f"
done < <(find "$dir" -maxdepth 1 -type f -name '[!.]*' -print0)
```

## 7. `local` Declaration in Loop Body

**Symptom:** In some bash versions, `local` inside a `while` loop within a function can cause issues with `set -e`.

**Fix:** Declare `local` variables at the top of the function, not inside loops. Or use a subshell for the loop body.
