# OpenRouter Signup Automation Reference

## Flow overview

1. Generate Duck Address email (`bash scripts/email.sh`)
2. Load Proton credentials from `~/config.py`
3. Generate random password
4. Sign up on OpenRouter (Clerk.js form + Turnstile)
5. Check Proton inbox for verification link
6. Visit verify URL → extract API key
7. Save to `credentials/openrouter_credentials.txt`

## Architecture: common profile + CloakBypasser

**Critical design decision**: signup (step 4) and verify (step 6) MUST share
the **same persistent profile** (`~/or_profile`), not separate tmpdirs. The
Cloudflare challenge state and session cookies earned during signup must carry
over to the verify step. Same for inbox check + verify steps — ideally ONE
browser context does all three.

**Optimization (2026-06-29)**: Use a **single persistent browser** for the entire
flow (signup → proton inbox → verify → key extraction). This cuts Chromium
processes from 4-5 down to 2 (bypass server + signup browser), saves ~600MB+ RAM,
and naturally carries session state across steps.

**Proton stays separate** — uses its own `~/proton_profile` (no CF bypass needed).

### Pattern: CloakBypasser for navigation + persistent context for interaction

```python
import asyncio
from cf_bypasser import CloakBypasser
from cloakbrowser import launch_persistent_context

async def signup_step(email, password):
    # 1. Use CloakBypasser to solve CF challenge and get cookies
    b = CloakBypasser(max_retries=5, log=True)
    result = await b.get_or_generate_html("https://openrouter.ai/sign-up")

    # 2. Re-launch with COMMON persistent profile + FakeShadowRoot
    ctx = launch_persistent_context(
        "/home/runner/or_profile",  # shared between signup & verify
        headless=False,
        humanize=True,
        args=["--enable-blink-features=FakeShadowRoot"]
    )
    p = ctx.pages[0] if ctx.pages else ctx.new_page()

    # 3. Restore cookies from bypasser
    if result and result.get("cookies"):
        await ctx.cookies([{"name": n, "value": v, "url": "https://openrouter.ai"}
                          for n, v in result["cookies"].items()])

    # 4. Navigate and interact
    await p.goto("https://openrouter.ai/sign-up", wait_until="domcontentloaded")
    # ... fill form, submit, poll for success ...
    await ctx.close()
```

### Why this two-phase approach?

- `CloakBypasser` handles the initial CF challenge (auto-solve + FakeShadowRoot click)
- Persistent profile preserves the cleared session for subsequent steps
- Restoring cookies from the bypasser into the persistent context bridges the two

### Install CloakBypassForScraping

```bash
pip install git+https://github.com/sarperavci/CloudflareBypassForScraping.git -i https://pypi.org/simple/
```

Not on PyPI — must install from GitHub. Dependencies: `cloakbrowser`, `curl_cffi`,
`fastapi`, `uvicorn`, `pydantic`, `pyvirtualdisplay`.

### Single-browser pattern (recommended)

```python
from cloakbrowser import launch_persistent_context

# ONE browser for the entire flow
ctx = launch_persistent_context(
    "/home/runner/or_profile",
    headless=False,
    humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"]
)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

# Step 1: Signup
page.goto("https://openrouter.ai/sign-up", timeout=60000)
# ... fill form, submit, handle Turnstile ...

# Step 2: Proton inbox (same browser, new navigation)
page.goto("https://account.proton.me/login", timeout=60000)
# ... search inbox, extract verify URL ...

# Step 3: Verify + extract key (same browser)
page.goto(verify_url, timeout=30000)
# ... click Individual, extract API key ...

ctx.close()
```

**Why**: Each `launch_persistent_context` spawns a Chromium (~200MB+, 3-5s startup).
Multiple launches waste resources and lose session cookies. One context preserves
the full auth state across all steps.

## Key pitfalls discovered

### Clerk.js form submission
- OpenRouter uses Clerk.js for auth
- `#emailAddress-field`, `#password-field`, `#legalAccepted-field`
- Checkbox: use `check(force=True)` — `.check()` doesn't update React state
- Continue button: `page.get_by_role("button", name="Continue").click()`
- **React fiber method**: if `.fill()` + `.check(force=True)` still doesn't work,
  walk the React fiber tree and call `memoizedProps.onChange` with synthetic events

### Turnstile inline (not iframe)
OpenRouter embeds Cloudflare Turnstile as `.cf-turnstile` div on the main page.
The old pattern of only checking `frame.url` for `challenges.cloudflare.com`
misses it entirely. See SKILL.md Cloudflare handling section for correct pattern.

**JS-based FakeShadowRoot walker** (works on main page AND frames):
```python
clicked = await p.evaluate("""() => {
    function find(root) {
        if (!root) return null;
        const direct = root.querySelector && root.querySelector('input[type=checkbox]');
        if (direct) return direct;
        for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
            const sr = el.fakeShadowRoot || el.shadowRoot;
            if (sr) { const r = find(sr); if (r) return r; }
        }
        return null;
    }
    for (const frame of window.frames) {
        try {
            const cb = find(frame.document);
            if (cb && !cb.checked) { cb.click(); return 'clicked_frame'; }
        } catch(e) {}
    }
    const cb = find(document);
    if (cb && !cb.checked) { cb.click(); return 'clicked_main'; }
    return null;
}""")
```

### Proton Mail verification
- Persistent profile at `~/proton_profile` (already logged in)
- Search with `/` keyboard shortcut, type email, Enter
- Parse frames for `https://clerk.openrouter.ai/v1/verify...` links
- Fallback: scan all `a[href]` for openrouter + verify/confirm

### API key extraction
After visiting verify URL:
1. Click "Individual" (personal account type)
2. Wait for redirect to dashboard
3. Extract from `<code>` block → regex `sk-or-v1-[a-zA-Z0-9]+`
4. Fallback: click Copy button → `navigator.clipboard.readText()`
5. Fallback: regex on full page HTML

## Output format
```
EMAIL=xxx@duck.com
PASSWORD=xxx
API_KEY=sk-or-v1-xxx
```

## Retry logic
3 attempts with fresh email/password each time. Verification email may not
arrive if Duck address is blocked by OpenRouter's email validation.

## Bash wrapper pattern

The user's preferred pattern is a single bash script (`openrouter_signup.sh`)
that generates Python helpers to `~/` and calls them:

```bash
cat > ~/or_signup.py << 'PY'
# ... Python using CloakBypasser + launch_persistent_context ...
PY

cat > ~/or_proton.py << 'PY'
# ... Proton inbox check ...
PY

cat > ~/or_verify.py << 'PY'
# ... Verify + extract key (uses same ~/or_profile) ...
PY

for ATTEMPT in 1 2 3; do
  python3 ~/or_signup.py "$EMAIL" "$PASSWORD" || continue
  VURL=$(python3 ~/or_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" 2>/dev/null \
         | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
  [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ] && continue
  python3 ~/or_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED"
  break
done
```

**Critical bash pitfalls:**
- `set -eo pipefail` + `grep` with no matches = script dies. Use `tail -1` not `head-1`,
  `sed` not `cut` for URLs (URLs contain colons), and `if` not `&&` for the empty check
- Python `print(..., flush=True)` + `sys.stdout.flush()` BEFORE `ctx.close()` + `sys.exit(0)`
  — otherwise the pipe capture gets empty string
- Break out of nested loops, print AFTER the loop, not inside — `sys.exit(0)` inside
  a `for frame` loop kills the process before stdout flushes
