#!/bin/bash
set -euo pipefail

SCRIPT_DIR="/home/runner/workspace/scripts"
PY_HELPER="$HOME/kilocode_signup.py"
LOG_FILE="$SCRIPT_DIR/kilocode_signup_$(date +%s).log"

mkdir -p "$SCRIPT_DIR"

# generate email using email.sh
bash /home/runner/workspace/scripts/email.sh > /tmp/generated_email.txt 2>&1
EMAIL=$(cat /tmp/generated_email.txt | tail -1 | xargs)
if [[ -z "${EMAIL:-}" || "$EMAIL" == "NOT_FOUND" ]]; then
    echo "Failed to generate email"
    exit 1
fi
echo "Generated email: $EMAIL"

cat > "$PY_HELPER" << 'PYEOF'
import os
import sys
from pathlib import Path

from cloakbrowser import launch_persistent_context

USER_DATA_DIR = Path.home() / ".kilocode_browser_profile"
USER_DATA_DIR.mkdir(parents=True, exist_ok=True)

EMAIL = os.environ.get("SIGNUP_EMAIL", "")
if not EMAIL:
    print("No email provided via SIGNUP_EMAIL env var", file=sys.stderr)
    sys.exit(1)

def main():
    with launch_persistent_context(
        user_data_dir=str(USER_DATA_DIR),
        headless=False,
        humanize=True,
        args=[
            "--display=:1",
            "--start-maximized",
            "--disable-blink-features=AutomationControlled",
        ],
    ) as context:
        page = context.new_page()
        page.goto("https://kilo.ai/", wait_until="domcontentloaded")

        # Click "Sign in"
        page.get_by_role("link", name="Sign in").click()
        page.wait_for_load_state("domcontentloaded")

        # Click "Continue with Email"
        page.get_by_role("button", name="Continue with Email").click()
        page.wait_for_load_state("domcontentloaded")

        # Fill email
        page.get_by_role("textbox", name="you@example.com").fill(EMAIL)
        page.get_by_role("button", name="Continue").click()
        page.wait_for_load_state("domcontentloaded")

        # Wait for verification code page
        page.wait_for_timeout(5000)

        print(f"EMAIL_USED={EMAIL}")
        print("Waiting for email verification code...")

        # Wait for user to enter code manually or check email
        page.wait_for_timeout(120000)

        print("Done waiting")

if __name__ == "__main__":
    main()
PYEOF

chmod +x "$PY_HELPER"

# Run with DISPLAY=:1
SIGNUP_EMAIL="$EMAIL" DISPLAY=:1 python3 "$PY_HELPER" 2>&1 | tee "$LOG_FILE"
echo "Log saved to $LOG_FILE"