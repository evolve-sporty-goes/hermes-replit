import sys
import os
import time
import re
import subprocess
import secrets
import string
import tempfile
import shutil
import atexit

sys.path.insert(0, "/home/runner")
sys.path.insert(0, "/home/runner/workspace")

from playwright.sync_api import sync_playwright

CRED_PATH = "/home/runner/workspace/credentials/openrouter_credentials.txt"
PROTON_PROFILE = os.path.expanduser("~/proton_profile")

# Step 3 subprocess: search Proton inbox for OpenRouter verify email
# Args: PROTON_USER, PROTON_PASS, CHROMIUM, PROFILE_DIR, SIGNUP_EMAIL
PROTON_FETCH_SCRIPT = r'''
import sys, os, re, time
from playwright.sync_api import sync_playwright

PROTON_USER = sys.argv[1]
PROTON_PASS = sys.argv[2]
PROFILE_DIR = sys.argv[3]
SIGNUP_EMAIL = sys.argv[4]

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(PROFILE_DIR,headless=False)
    page = context.pages[0] if context.pages else context.new_page()

    # Go to Proton — may already be logged in via persistent profile
    page.goto("https://account.proton.me/login", timeout=60000)
    page.wait_for_timeout(3000)

    already_logged_in = False
    try:
        mail_link = page.locator("a:has-text('Mail')")
        if mail_link.is_visible(timeout=3000):
            already_logged_in = True
    except:
        pass

    if already_logged_in:
        print("Already logged in to Proton — skipping credentials")
    else:
        page.locator("#username").fill(PROTON_USER)
        page.locator("#password").fill(PROTON_PASS)
        page.locator("button[type='submit']").click()
        page.wait_for_timeout(10000)

    page.locator("a:has-text('Mail')").first.click(timeout=0)
    page.wait_for_timeout(5000)

    # Use Proton's search box to find email sent to our signup address
    found = False
    for attempt in range(1, 6):
        print(f"Inbox search attempt {attempt}/5 for {SIGNUP_EMAIL}")
        try:
            # Open search with / shortcut, then type the email
            page.keyboard.press("/")
            page.wait_for_timeout(1000)
            page.keyboard.type(SIGNUP_EMAIL, delay=50)
            page.keyboard.press("Enter")
            page.wait_for_timeout(5000)

            # Click the latest (first) mail in results
            latest_mail = page.locator(".item-container").first
            if latest_mail.is_visible(timeout=5000):
                latest_mail.click()
                page.wait_for_timeout(5000)
                found = True
                break
        except:
            pass

        if attempt < 5:
            print("  Not found — clearing search and retrying...")
            page.keyboard.press("Escape")
            page.wait_for_timeout(3000)

    if not found:
        print("VERIFY_URL:NOT_FOUND")
        context.close()
        sys.exit(0)

    # Extract verification link from frames
    verify_url = None
    for frame in page.frames:
        try:
            html = frame.content()
            if "verify" in html.lower() or "confirm" in html.lower():
                matches = re.findall(r'https://clerk.openrouter.ai/v1/verify[^\s"\'<>]+', html)
                if not matches:
                    matches = re.findall(r'https://openrouter\.ai[^\s"\'<>]*(?:verify|confirm|token)[^\s"\'<>]+', html)
                if matches:
                    verify_url = matches[0].replace("&amp;", "&")
                    break
        except:
            pass

    if not verify_url:
        links = page.query_selector_all("a[href]")
        for link in links:
            href = link.get_attribute("href")
            if href and ("verify" in href or "confirm" in href) and "openrouter" in href:
                verify_url = href
                break

    context.close()

if verify_url:
    print("VERIFY_URL:" + verify_url)
else:
    print("VERIFY_URL:NOT_FOUND")
'''


def do_signup(page, email, password):
    """Step 2: Sign up on OpenRouter. Returns True if confirm-email shown."""
    print("\n" + "=" * 60)
    print("STEP 2: Sign up on OpenRouter")
    print("=" * 60)

    page.goto("https://openrouter.ai/sign-up", wait_until="networkidle", timeout=60000)
    page.wait_for_timeout(5000)

    page.locator("#emailAddress-field").wait_for(state="visible", timeout=30000)
    page.locator("#emailAddress-field").fill(email)
    page.locator("#password-field").fill(password)
    page.locator("#legalAccepted-field").check()
    page.get_by_role("button", name="Continue").click()
    page.wait_for_timeout(15000)

    # Handle Cloudflare challenge
    print("Checking for Cloudflare challenge...")
    for frame in page.frames:
        if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
            try:
                frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()
                page.wait_for_timeout(4000)
                print("  Cloudflare challenge clicked — waiting for validation...")
            except Exception:
                pass
            break
    page.wait_for_timeout(4000)

    body = page.inner_text("body")
    if "confirm-email" in page.url or "verification" in body.lower() or "check your" in body.lower():
        print("SUCCESS: Signup complete — confirm-email indicator visible")
        return True
    else:
        print(f"After signup URL: {page.url}")
        print(f"Body (first 400 chars): {body[:400]}")
        return False


def do_verify_and_key(page, verify_url, email, password):
    """Steps 5+6: Verify email, sign in, extract API key."""
    print("\n" + "=" * 60)
    print("STEP 5: Verify email + sign in + get API key")
    print("=" * 60)

    page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
    page.wait_for_timeout(5000)

    # If on openrouter.ai, click "Individual" to pick personal account
    if "openrouter.ai" in page.url:
        print("On OpenRouter — clicking Individual...")
        try:
            page.get_by_text("Individual", exact=False).first.click()
            page.wait_for_timeout(3000)
        except:
            try:
                page.locator("button:has-text('Individual')").first.click()
                page.wait_for_timeout(3000)
            except:
                pass

    # Wait for login to settle (verification link auto-logs in)
    page.wait_for_timeout(8000)
    print(f"URL after verify: {page.url}")
    
    # --- STEP 6: Extract API key ---
    print("\n" + "=" * 60)
    print("STEP 6: Extract API key")
    print("=" * 60)
    
    api_key = None

    # Primary: extract from <code> block
    print("  Looking for key in <code> block...")
    try:
        code_text = page.locator("code").inner_text(timeout=5000)
        match = re.search(r"sk-or-v1-[a-zA-Z0-9]+", code_text)
        if match:
            api_key = match.group(0)
            print(f"  Found via <code>: {api_key[:14]}...{api_key[-6:]}")
    except Exception as e:
        print(f"  <code> block not found: {e}")

    # Fallback: copy button + clipboard
    if not api_key:
        print("  Trying copy button + clipboard...")
        try:
            page.locator('button:has-text("Copy")').first.click()
            page.wait_for_timeout(1500)
            clipboard = page.evaluate("navigator.clipboard.readText()")
            match = re.search(r"sk-or-v1-[a-zA-Z0-9]+", clipboard or "")
            if match:
                api_key = match.group(0)
                print(f"  Found via clipboard: {api_key[:14]}...{api_key[-6:]}")
        except:
            pass

    # Fallback: regex on full HTML
    if not api_key:
        print("  Falling back to HTML extraction...")
        html = page.content()
        match = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", html)
        if match:
            api_key = match.group(0)
            print(f"  Found via HTML: {api_key[:14]}...")

    return api_key


def main():
    # Browser profile tmpdir (cleaned up on exit)
    browser_tmpdir = tempfile.mkdtemp(prefix="browser-profile-")
    print(f"Browser tmpdir: {browser_tmpdir}")
    atexit.register(lambda: shutil.rmtree(browser_tmpdir, ignore_errors=True))

    os.makedirs(PROTON_PROFILE, exist_ok=True)

    # ============================================================
    # STEP 1: Generate Duck email
    # ============================================================
    print("=" * 60)
    print("STEP 1: Generate Duck email")
    print("=" * 60)

    venv_bin = os.path.dirname(sys.executable)
    venv_dir = os.path.dirname(venv_bin)
    pythonlibs = "/home/runner/workspace/.pythonlibs/lib/python3.12/site-packages"
    result = subprocess.run(
        ["bash", "/home/runner/workspace/scripts/email.sh"],
        capture_output=True, text=True, timeout=120,
        cwd="/home/runner/workspace",
        env={**os.environ, "PYTHONPATH": pythonlibs + ":/home/runner:/home/runner/workspace",
             "PATH": venv_bin + ":" + os.environ.get("PATH", ""),
             "VIRTUAL_ENV": venv_dir}
    )
    if result.returncode != 0:
        print(f"email.sh stderr: {result.stderr[:500]}")

    # Capture email from email.sh stdout (last line)
    out_lines = [l.strip() for l in result.stdout.strip().split("\n") if l.strip()]
    email = out_lines[-1] if out_lines else None

    import importlib, importlib.util
    pyc_cache = os.path.expanduser("~/__pycache__/config.cpython-312.pyc")
    if os.path.exists(pyc_cache):
        os.remove(pyc_cache)
    if "config" in sys.modules:
        del sys.modules["config"]
    spec = importlib.util.spec_from_file_location("config", os.path.expanduser("~/config.py"))
    cfg = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cfg)

    PROTON_USER = cfg.PROTON_USERNAME
    PROTON_PASS = cfg.PROTON_PASSWORD
    print(f"Proton user: {PROTON_USER}")

    if not email or "@" not in email:
        print(f"ERROR: No email from email.sh stdout! Last line: {email}")
        sys.exit(1)
    print(f"Generated email: {email}")

    # Generate password
    chars = string.ascii_letters + string.digits + "!@#$%"
    password = (
        secrets.choice(string.ascii_letters)
        + secrets.choice(string.digits)
        + secrets.choice("!@#%")
        + "".join(secrets.choice(chars) for _ in range(12))
    )
    print(f"Generated password: {password}")

    # Main retry loop: signup → check inbox → verify+key
    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(browser_tmpdir,headless=False)
        page = context.pages[0] if context.pages else context.new_page()

        for attempt in range(1, 4):
            # Step 2: Sign up
            do_signup(page, email, password)

            # Step 3: Check Proton Mail (Chromium subprocess, with inbox retry)
            print("\n" + "=" * 60)
            print("STEP 3: Check Proton Mail for verification email")
            print("=" * 60)

            result = subprocess.run(
                [sys.executable, "-c", PROTON_FETCH_SCRIPT, PROTON_USER, PROTON_PASS, PROTON_PROFILE, email],
                capture_output=True, text=True, timeout=180,
            )
            for line in result.stdout.strip().split("\n"):
                if line.strip():
                    print(f"  {line}")

            verify_url = None
            for line in result.stdout.strip().split("\n"):
                if line.startswith("VERIFY_URL:"):
                    url = line[len("VERIFY_URL:"):]
                    if url == "NOT_FOUND":
                        print(f"Verification email not found (attempt {attempt}/3) — restarting signup...")
                        break
                    verify_url = url
                    print(f"Found verification link: {verify_url[:60]}...")
                    break

            if not verify_url:
                # Generate fresh email for next attempt
                print("Generating new email for retry...")
                result = subprocess.run(
                    ["bash", "/home/runner/workspace/scripts/email.sh"],
                    capture_output=True, text=True, timeout=120,
                    cwd="/home/runner/workspace",
                    env={**os.environ, "PYTHONPATH": pythonlibs + ":/home/runner:/home/runner/workspace",
                         "PATH": venv_bin + ":" + os.environ.get("PATH", ""),
                         "VIRTUAL_ENV": venv_dir}
                )
                retry_lines = [l.strip() for l in result.stdout.strip().split("\n") if l.strip()]
                retry_email = retry_lines[-1] if retry_lines else None
                if retry_email and "@" in retry_email:
                    email = retry_email
                password = (
                    secrets.choice(string.ascii_letters)
                    + secrets.choice(string.digits)
                    + secrets.choice("!@#%")
                    + "".join(secrets.choice(chars) for _ in range(12))
                )
                print(f"New email: {email}")
                continue

            # Steps 5+6: Verify + get API key
            api_key = do_verify_and_key(page, verify_url, email, password)

            # Step 7: Save
            print("\n" + "=" * 60)
            print("STEP 7: Save credentials")
            print("=" * 60)

            with open(CRED_PATH, "a") as f:
                f.write(f"EMAIL={email}\n")
                f.write(f"PASSWORD={password}\n")
                f.write(f"API_KEY={api_key or 'NOT_FOUND'}\n")

            print(f"Credentials saved to: {CRED_PATH}")
            print(f"  Email:    {email}")
            print(f"  Password: {password}")
            print(f"  API Key:  {api_key or 'NOT_FOUND'}")
            print("\nDone!")
            return

        context.close()

    print("FAILED: 3 signup attempts exhausted.")


if __name__ == "__main__":
    main()
