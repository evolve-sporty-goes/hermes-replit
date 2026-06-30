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
p = ctx.pages[0] if ctx.pages else context.new_page()
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

If subprocess Python scripts fail with "Missing X server or $DISPLAY",
add `export DISPLAY=:1` (or whatever display the user specifies) at the top
of the bash script — subprocesses don't always inherit the parent's env.

## CRITICAL: `pipefail` + `grep` kills script silently

With `set -eo pipefail`, a `grep` with no matches (exit code 1) causes
the entire pipeline to return 1, and `set -e` kills the script immediately
with no visible error.

**BROKEN:**
```bash
VURL=$(python3 ~/proton.py "$EMAIL" "$PROFILE" 2>/dev/null | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
```

**FIXED:**
```bash
# Remove pipefail, or use tail/sed instead of head/cut
VURL=$(python3 ~/proton.py "$EMAIL" "$PROFILE" 2>&1 | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
```

## CRITICAL: Python stdout not flushed before `ctx.close()` + `sys.exit(0)`

Pipe capture gets empty string. Always `flush=True` and `sys.stdout.flush()`
before closing. Break out of nested loops and print after, not inside.

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

## Common profile across signup+verify steps

When a signup flow has multiple browser steps (signup → verify → extract),
use the **same persistent profile** for all steps, not separate tmpdirs.
Cloudflare challenge state and session cookies earned during signup must
carry over to verify. Proton Mail gets its own separate profile.

Example: `~/or_profile` shared between `or_signup.py` and `or_verify.py`.

## Bash+Python helper pattern (canonical)

```bash
#!/bin/bash
export DISPLAY=:1
# ... config ...

# Step 1: Generate .py helpers
cat > ~/step1_signup.py << 'PYEOF'
from cloakbrowser import launch_persistent_context
import sys, tempfile, shutil, atexit
# ... logic ...
PYEOF

cat > ~/step2_proton.py << 'PYEOF'
from cloakbrowser import launch_persistent_context
import sys, re, time
# ... logic ...
PYEOF

cat > ~/step3_verify.py << 'PYEOF'
from cloakbrowser import launch_persistent_context
import sys, re, time
# ... logic ...
PYEOF

# Step 2: Run with retry
for ATTEMPT in 1 2 3; do
    python3 ~/step1_signup.py "$EMAIL" "$PASSWORD" "$PROFILE" || continue
    VURL=$(python3 ~/step2_proton.py "$EMAIL" "$PROTON_PROFILE" 2>&1 | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
    [ -z "$VURL" ] && continue
    python3 ~/step3_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$PROFILE"
    exit 0
done
```

**Key rules:**
- `headless=False` with CloakBrowser (no xvfb needed)
- `humanize=True` for signup flows
- One persistent profile per logical flow (signup/verify share; Proton separate)
- `flush=True` on all print statements that must survive `sys.exit(0)`
- `2>&1` not `2>/dev/null` for subprocesses you need to debug

## bash syntax check

Always validate before running:
```bash
bash -n scripts/your_script.sh && echo "OK"
```