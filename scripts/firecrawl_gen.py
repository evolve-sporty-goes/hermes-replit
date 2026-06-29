"""Firecrawl signup + email verification + API key extraction.

Step 3 (Proton Mail) uses Playwright Chromium with a persistent profile
at ~/proton_profile. Steps 2/5/6 use Playwright Chromium with a fresh tmpdir each run.
Inbox searches for the signup email with 5 retries; if not found, restarts signup.
"""

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
import importlib
import importlib.util

sys.path.insert(0, "/home/runner")
sys.path.insert(0, "/home/runner/workspace")

from playwright.sync_api import sync_playwright

CRED_PATH = "/home/runner/workspace/credentials/firecrawl_credentials.txt"
CHROMIUM_PATH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PROTON_PROFILE = os.path.expanduser("~/proton_profile")

# Step 3 subprocess: search Proton inbox for Firecrawl verify email
# Args: PROTON_USER, PROTON_PASS, CHROMIUM, PROFILE_DIR, SIGNUP_EMAIL
PROTON_FETCH_SCRIPT = r'''
import sys, os, re, time
from playwright.sync_api import sync_playwright

PROTON_USER = sys.argv[1]
PROTON_PASS = sys.argv[2]
CHROMIUM = sys.argv[3]
PROFILE_DIR = sys.argv[4]
SIGNUP_EMAIL = sys.argv[5]

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        PROFILE_DIR,
        executable_path=CHROMIUM,
        headless=False,
        no_viewport=True,
    )
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
                matches = re.findall(r'https://service\.firecrawl\.dev/auth/v1/verify[^\s"\'<>,]+', html)
                if not matches:
                    matches = re.findall(r'https://firecrawl\.dev[^\s"\'<>,]*(?:verify|confirm)[^\s"\'<>,]+', html)
                if matches:
                    verify_url = matches[0].replace("&amp;", "&")
                    break
        except:
            pass

    if not verify_url:
        links = page.query_selector_all("a[href]")
        for link in links:
            href = link.get_attribute("href")
            if href and ("verify" in href or "confirm" in href) and "firecrawl" in href:
                verify_url = href
                break

    context.close()

if verify_url:
    print("VERIFY_URL:" + verify_url)
else:
    print("VERIFY_URL:NOT_FOUND")
'''


def generate_password():
    """Generate a password with at least one special character."""
    chars = string.ascii_letters + string.digits + "!@#$%"
    pwd = (
        secrets.choice(string.ascii_letters)
        + secrets.choice(string.digits)
        + secrets.choice("!@#%")
        + "".join(secrets.choice(chars) for _ in range(12))
    )
    return pwd


def do_signup(page, email, password):
    """Step 2: Sign up on Firecrawl. Returns True if confirm-email shown."""
    print("\n" + "=" * 60)
    print("STEP 2: Sign up on Firecrawl")
    print("=" * 60)

    page.goto("https://www.firecrawl.dev/signin", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(3000)

    # Click "Sign Up" tab
    page.click("text=Sign Up")
    page.wait_for_timeout(2000)

    # Fill email
    page.locator('input[type="email"]').fill(email)

    # Fill password (must contain special char)
    page.locator('input[type="password"]').fill(password)

    # Click Create Account
    page.get_by_role("button", name="Create Account").click()
    page.wait_for_timeout(10000)

    signup_url = page.url
    print(f"After signup URL: {signup_url}")

    # Check if we got the confirm-email page
    if "confirm-email" in signup_url:
        print("SUCCESS: Signup complete — confirm-email indicator visible")
        return True
    else:
        body = page.inner_text("body")
        print(f"Body (first 400 chars): {body[:400]}")
        return False


def do_verify_and_key(page, verify_url, email, password):
    """Steps 4+5: Verify email, sign in, extract API key."""
    print("\n" + "=" * 60)
    print("STEP 4: Verify email + sign in + get API key")
    print("=" * 60)

    page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
    page.wait_for_timeout(5000)

    # Wait for login to settle (verification link auto-logs in)
    for i in range(30):
        url = page.url
        if "/signin" not in url:
            print(f"Logged in! URL: {url}")
            break
        time.sleep(2)
    page.wait_for_timeout(8000)

    # --- STEP 5: Extract API key ---
    print("\n" + "=" * 60)
    print("STEP 5: Extract API key via eye icon reveal")
    print("=" * 60)

    api_key = None

    # Primary: click the eye icon (.lucide-eye) to reveal the key
    print("  Clicking eye icon to reveal API key...")
    try:
        page.click("button:has(.lucide-eye)")
        page.wait_for_timeout(3000)
        api_key = page.locator("text=fc-").first.text_content().strip()
        if api_key.startswith("fc-"):
            print(f"  Found via eye reveal: {api_key[:14]}...{api_key[-6:]}")
    except Exception as e:
        print(f"  Eye icon click failed: {e}")

    # Fallback: click .lucide-eye-off button
    if not api_key:
        print("  Trying alternate eye-off button...")
        try:
            page.click("button:has(.lucide-eye-off)")
            page.wait_for_timeout(3000)
            api_key = page.locator("text=fc-").first.text_content().strip()
            if api_key.startswith("fc-"):
                print(f"  Found via alt eye-off click: {api_key[:14]}...")
        except:
            pass

    # Fallback: copy button + clipboard
    if not api_key:
        print("  Trying copy button + clipboard...")
        try:
            page.click('[aria-label="Copy"]')
            page.wait_for_timeout(1500)
            clipboard = page.evaluate("navigator.clipboard.readText()")
            if clipboard and clipboard.startswith("fc-"):
                api_key = clipboard.strip()
                print(f"  Found via clipboard: {api_key[:14]}...")
        except:
            pass

    # Last resort: regex on full HTML
    if not api_key:
        print("  Falling back to HTML extraction...")
        html = page.content()
        matches = re.findall(r"fc-[a-zA-Z0-9]{20,}", html)
        if matches:
            api_key = max(matches, key=len)
            print(f"  Found via HTML: {api_key[:14]}...")

    return api_key


def main():
    # Browser profile tmpdir (cleaned up on exit)
    browser_tmpdir = tempfile.mkdtemp(prefix="browser-profile-")
    print(f"Browser tmpdir: {browser_tmpdir}")
    atexit.register(lambda: shutil.rmtree(browser_tmpdir, ignore_errors=True))

    os.makedirs(PROTON_PROFILE, exist_ok=True)

    # ============================================================
    # STEP 1: Generate Duck email + load config
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

    # Reload config (in case email.sh updated ~/config.py)
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
    password = generate_password()
    print(f"Generated password: {password}")

    # Main retry loop: signup → check inbox → verify+key
    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            browser_tmpdir,
            executable_path=CHROMIUM_PATH,
            headless=False,
        )
        page = context.pages[0] if context.pages else context.new_page()

        for attempt in range(1, 4):
            # Step 2: Sign up
            do_signup(page, email, password)

            # Step 3: Check Proton Mail (Chromium subprocess, with inbox retry)
            print("\n" + "=" * 60)
            print("STEP 3: Check Proton Mail for verification email")
            print("=" * 60)

            result = subprocess.run(
                [sys.executable, "-c", PROTON_FETCH_SCRIPT, PROTON_USER, PROTON_PASS, CHROMIUM_PATH, PROTON_PROFILE, email],
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
                password = generate_password()
                print(f"New email: {email}")
                continue

            # Steps 4+5: Verify + get API key
            api_key = do_verify_and_key(page, verify_url, email, password)

            # Step 6: Save
            print("\n" + "=" * 60)
            print("STEP 6: Save credentials")
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
