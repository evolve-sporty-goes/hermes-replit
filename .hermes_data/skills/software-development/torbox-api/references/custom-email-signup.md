# Custom Email Signup + Verification (Session 2026-06-28)

## Scenario

User provides a specific email + password to sign up a TorBox account, rather than using the automated `backup.sh` script (which generates a new Proton email via `email.sh`).

## Flow

1. **Supabase signup** — `POST /auth/v1/signup` with the user's email + password
2. **Verification** — Supabase sends a confirmation email; extract the verify URL from Proton Mail
3. **Credentials file** — Append email, password, user_id, and magic_link to `torbox_credentials.txt`

## Key difference from OTP/magic-link flow

- The **OTP flow** (`/auth/v1/otp`) sends a magic link to an *existing* account for passwordless login
- The **signup flow** (`/auth/v1/signup`) creates a *new* account and sends a confirmation email
- Both flows produce a verify URL at `db.torbox.app/auth/v1/verify` — the extraction logic is identical
- The signup response includes `confirmation_sent_at` (timestamp) confirming the email was dispatched

## `config.py` missing on Replit

On Replit, `~/config.py` (containing `PROTON_USERNAME` and `PROTON_PASSWORD`) may be lost in a reset. The extraction script (`torbox-extract-verify-url.py`) imports `config` to get Proton credentials.

**Symptom:** `ModuleNotFoundError: No module named 'config'`

**Recovery:**
1. Tell the user plainly that `config.py` is missing
2. Ask for `PROTON_USERNAME` and `PROTON_PASSWORD`
3. Recreate `~/config.py`:
```python
PROTON_USERNAME = "user@proton.me"
PROTON_PASSWORD = "password"
```
4. Re-run extraction

**Do NOT** attempt to proceed without credentials — the Proton inbox is inaccessible.

## `scripts/backup.sh` naming

The file `scripts/backup.sh` is **not** a backup script — it's the TorBox signup pipeline (signup → Proton verify → credentials file). The name is historical/misleading. It:
- Calls `email.sh` to generate a new Proton email
- Signs up via Supabase `/auth/v1/signup`
- Verifies via Proton Playwright automation
- Appends credentials to `torbox_credentials.txt`

When the user says "run backup.sh", they mean "run the TorBox signup pipeline". The script only works when `config.py` exists (for Proton login) and `email.sh` exists (for email generation).

## Credentials file format

Appended to `~/workspace/torbox_credentials.txt` (one block per account):

```
email=user@example.com
password=...
user_id=<uuid>
magic_link=<verify_url or NOT_VERIFIED>

```

Blank line separator between entries. APPEND only — never overwrite.
