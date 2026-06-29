# CloakBrowser + Bash Pattern Reference

## User preference
The user prefers **bash scripts with minimal lines of code** over Python or any
other approach. "Just give me bash" is the directive. Automation scripts should
be bash-first, using Python helpers only for browser interactions.

## Generate `.py` helpers in `~/`, call from bash

The canonical pattern (from `email.sh` and `firecrawl_signup.sh`):

```bash
#!/bin/bash
set -eo pipefail
export DISPLAY=:1          # if subprocess needs X
cd /home/runner/workspace

# Step 1: Generate .py helper file
cat > ~/fc_signup.py << 'PYEOF'
import sys, tempfile, atexit, shutil
from cloakbrowser import launch_persistent_context
email, password = sys.argv[1], sys.argv[2]
td = tempfile.mkdtemp()
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))
ctx = launch_persistent_context(td, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto("https://example.com", timeout=60000)
# ... do stuff ...
ctx.close()
PYEOF

# Step 2: Call it
python3 ~/fc_signup.py "$EMAIL" "$PASSWORD"
```

## CRITICAL: Nested heredocs break

**NEVER** do this:
```bash
# BROKEN — bash quote escaping fails inside command substitution
RESULT=$(python3 << 'OUTER'
import sys
print("hello")
OUTER
)
```

**ALWAYS** generate `.py` files first, then call them separately:
```bash
# CORRECT
cat > ~/helper.py << 'PY'
# python code here
PY
python3 ~/helper.py "$ARG"
```

## CRITICAL: `shutil.rmtree` uses `ignore_errors`

```python
# WRONG
shutil.rmtree(td, ignore=True)

# RIGHT
shutil.rmtree(td, ignore_errors=True)
```

## DISPLAY env for subprocesses

If you get `Missing X server or $DISPLAY` errors when running Python from bash:
```bash
export DISPLAY=:1   # or :0, or whatever the user specifies
```
Subprocesses don't always inherit the parent's DISPLAY.

## Sed one-liner: bulk migrate playwright → cloakbrowser

```bash
grep -rl 'sync_playwright' scripts/ | xargs sed -i 's/from playwright.sync_api import sync_playwright/from cloakbrowser import launch, launch_persistent_context/g; s/p\.chromium\.launch_persistent_context/launch_persistent_context/g; /^with sync_playwright() as p:$/d; /executable_path=/d; s/headless=False,/headless=False, humanize=True,/g'
```

**After running sed**: you must manually:
- Un-indent the body that was inside the `with` block (4 spaces → 0)
- Remove `p.stop()` lines

## CRITICAL: `pipefail` + `grep` kills scripts silently

With `set -eo pipefail`, if `grep` finds no matches the whole pipeline exits 1
and the script dies. This is especially dangerous when capturing output:

```bash
# DANGEROUS: dies if grep finds nothing
RESULT=$(python3 ~/helper.py | grep '^RESULT:' | head -1 | cut -d: -f2-)
```

**Fix 1**: Use `tail -1` instead of `head -1` (tail doesn't fail on empty input
the same way), and `sed` instead of `cut` (URLs contain colons):

```bash
RESULT=$(python3 ~/helper.py 2>/dev/null | grep '^RESULT:' | tail -1 | sed 's/^RESULT://')
```

**Fix 2**: Use `if` instead of `&&` one-liner for the check:

```bash
# BAD: pipefail kills script if condition is false
[ -z "$RESULT" ] && { echo "missing"; continue; }

# GOOD: explicit if doesn't trigger pipefail
if [ -z "$RESULT" ]; then echo "missing"; continue; fi
```

## CRITICAL: Python stdout flush before `sys.exit(0)` + `ctx.close()`

When a Python helper prints a result then immediately closes the browser and exits,
the pipe can be killed before stdout flushes. The bash capture gets empty string.

```python
# BAD: pipe may be killed before flush
print(f"VERIFY_URL:{url}")
ctx.close()
sys.exit(0)

# GOOD: flush explicitly, close, then exit
print(f"VERIFY_URL:{url}", flush=True)
sys.stdout.flush()
ctx.close()
sys.exit(0)
```

Also: break out of inner loops, set a variable, then print AFTER the loop — don't
print+exit inside nested `for frame` loops where the break/close ordering matters.

```python
# BAD: print+exit inside nested loop
for frame in page.frames:
    if condition:
        print(f"RESULT:{value}")
        ctx.close(); sys.exit(0)

# GOOD: break out, print after loop
result = None
for frame in page.frames:
    if condition:
        result = value
        break
if result:
    print(f"RESULT:{result}", flush=True)
    sys.stdout.flush()
    ctx.close()
    sys.exit(0)
```

## bash syntax check

Always validate before running:
```bash
bash -n scripts/your_script.sh && echo "OK"
```
