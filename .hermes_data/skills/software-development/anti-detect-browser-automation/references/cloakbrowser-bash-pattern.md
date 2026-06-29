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

## bash syntax check

Always validate before running:
```bash
bash -n scripts/your_script.sh && echo "OK"
```
