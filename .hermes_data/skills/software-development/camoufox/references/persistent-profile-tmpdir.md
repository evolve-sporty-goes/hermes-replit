# Persistent Profile via Temp Directory

## When to Use

Multi-step browser workflows (signup → verify → signin → extract) need cookies and localStorage to persist between steps. By default, each `Camoufox()` call launches a fresh anonymous profile. Use `persistent_context=True` with a shared `user_data_dir` to maintain session state across steps.

## Recommended Pattern: Single Browser Session

The preferred approach is to share a **single `Camoufox` instance** across all steps that need the same profile. This is more efficient (one Firefox launch) and guarantees the same process/context is reused:

```python
import tempfile, shutil, atexit, os

def main():
    # Create a persistent profile temp directory
    tmpdir = tempfile.mkdtemp(prefix="camoufox-profile-")
    print(f"Persistent profile: {tmpdir}")

    def cleanup():
        if os.path.exists(tmpdir):
            shutil.rmtree(tmpdir, ignore_errors=True)
            print(f"Cleaned up profile: {tmpdir}")
    atexit.register(cleanup)

    try:
        run(tmpdir)
    except Exception:
        cleanup()
        raise

def run(tmpdir: str):
    # Single persistent session for all steps that share state
    with Camoufox(
        headless=False,
        persistent_context=True,
        user_data_dir=tmpdir
    ) as browser:
        # Step 2: Sign up — profile accumulates cookies, localStorage
        page = browser.new_page()
        # ... signup flow ...

        # Step 5: Sign in — same browser, same session, new page
        page2 = browser.new_page()
        # ... signin + API key extraction ...
        # browser.close() saves profile state to disk
```

**Key difference from the old pattern:** Steps share one `with Camoufox(...)` block. Each step calls `browser.new_page()` for isolation, but the underlying profile (cookies, localStorage, cache) is shared. No second Firefox launch needed.

## Alternative Pattern: Sequential Persistent Contexts

If steps must run in separate `Camoufox` invocations (e.g., different `headless` settings, or intermediate steps use a different browser), the profile persists via the shared `user_data_dir` on disk:

```python
def run(tmpdir: str):
    # Step 2: Sign up — profile accumulates cookies, localStorage
    with Camoufox(
        headless=False,
        persistent_context=True,
        user_data_dir=tmpdir
    ) as browser:
        page = browser.new_page()
        # ... signup flow ...
        # browser.close() saves profile state to disk

    # Step 5: Sign in — profile retains cookies from step 2
    with Camoufox(
        headless=True,
        humanize=True,
        geoip=True,
        os="windows",
        persistent_context=True,
        user_data_dir=tmpdir
    ) as browser:
        page = browser.new_page()
        # ... signin + API key extraction ...
```

**Trade-off:** This works (profile persists via disk), but launches Firefox twice. Use the single-session pattern when possible.

## Why This Works

- `persistent_context=True` tells Camoufox to use `playwright.firefox.launch_persistent_context()` instead of `playwright.firefox.launch()`.
- `user_data_dir` points to a directory on disk where Firefox stores its profile (cookies, localStorage, cache, etc.).
- When the `Camoufox` context manager exits (`browser.close()`), the profile is written to disk.
- The next `Camoufox(user_data_dir=tmpdir)` launch reads that profile, restoring all session state.

## Cleanup Strategy

Three layers of cleanup:

1. **`atexit.register(cleanup)`** — runs when the script exits normally.
2. **`except Exception: cleanup(); raise`** — runs on error before the exception propagates.
3. **`ignore_errors=True`** in `shutil.rmtree` — prevents cleanup failures from masking the original error.

## Pitfalls

1. **Don't use `/tmp/` directly** — use `tempfile.mkdtemp()` which creates a unique subdirectory. Multiple concurrent script runs won't collide.
2. **Don't pass `user_data_dir` without `persistent_context=True`** — `launch()` ignores `user_data_dir`; only `launch_persistent_context()` uses it.
3. **Profile directory can grow large** — for long-running workflows, the profile can accumulate hundreds of MB of cache. The `atexit` cleanup handles this, but if the process is killed (`SIGKILL`), the temp dir may leak. On Linux, `/tmp/` is typically cleaned by the OS on reboot.
4. **Not compatible with concurrent launches** — Firefox takes an exclusive lock on the profile directory. Don't launch two `Camoufox` instances with the same `user_data_dir` simultaneously.
5. **`geoip=True` requires fresh IP context** — if you use `geoip=True`, the first launch sets geolocation based on IP. Subsequent launches with the same profile retain this, so you don't need to worry about IP changes between steps.
6. **Single-session pattern is NOT compatible with changing `headless` mid-flow** — if one step needs `headless=False` and another needs `headless=True`, you must use the sequential pattern (two launches) since `headless` is a launch-time option.
