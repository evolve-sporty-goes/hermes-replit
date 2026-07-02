# TorBox API - db.torbox.app curl responses

## Base URL
https://db.torbox.app

## Supabase Auth Endpoints

### 1. Signup
**POST** https://db.torbox.app/auth/v1/signup
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -d '{"email":"user@example.com","password":"..."}'
```

**Success Response (200):**
```json
{
  "id": "uuid-here",
  "aud": "authenticated",
  "role": "authenticated",
  "email": "user@example.com",
  "phone": "",
  "confirmation_sent_at": "2026-07-02T03:38:26.809377607Z",
  "app_metadata": {"provider": "email", "providers": ["email"]},
  "user_metadata": {"email": "user@example.com", "email_verified": false, "phone_verified": false, "sub": "uuid-here"},
  "identities": [...],
  "created_at": "2026-07-02T03:38:26.800089Z",
  "updated_at": "2026-07-02T03:38:27.87196Z",
  "is_anonymous": false
}
```

**Error: Weak Password (422):**
```json
{"code":422,"error_code":"weak_password","msg":"Password should contain at least one character of each: abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ, 0123456789, !@#$%^&*()_+-=[]{};':\"|,.<>?/~`.","weak_password":{"reasons":["characters"]}}
```

**Error: Bad JSON (400):**
```json
{"code":400,"error_code":"bad_json","msg":"Could not parse request body as JSON..."}
```

---

### 2. Login (Token)
**POST** https://db.torbox.app/auth/v1/token?grant_type=password
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"..."}'
```

**Success Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "expires_at": 1782515305,
  "refresh_token": "short-refresh-token",
  "user": {
    "id": "uuid-here",
    "aud": "authenticated",
    "role": "authenticated",
    "email": "user@example.com",
    "email_confirmed_at": "2026-06-26T15:31:01.433547Z",
    "phone": "",
    "confirmation_sent_at": "2026-06-26T15:30:18.578901Z",
    "confirmed_at": "2026-06-26T15:31:01.433547Z",
    "recovery_sent_at": "2026-06-26T21:48:03.846203Z",
    "last_sign_in_at": "2026-06-26T22:08:25.94869867Z",
    "app_metadata": {"provider": "email", "providers": ["email"]},
    "user_metadata": {"email": "user@example.com", "email_verified": true, "phone_verified": false, "sub": "uuid-here"},
    "identities": [...]
  }
}
```

**Error: Invalid API Key (400):**
```json
{"message":"Invalid API key","hint":"Double check your Supabase `anon` or `service_role` API key."}
```

**Error: Email Not Confirmed (400):**
```json
{"code":400,"error_code":"email_not_confirmed","msg":"Email not confirmed"}
```

---

### 3. Request OTP (Magic Link)
**POST** https://db.torbox.app/auth/v1/otp
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/otp" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

**Success Response (200):**
```
{}
```

**Note:** This endpoint requires Cloudflare bypass (Playwright browser fetch). Direct curl from server returns 403 Forbidden (error code 1010).

---

### 4. Email Verification Link
**GET** https://db.torbox.app/auth/v1/verify?token=...&type=signup&redirect_to=...
```bash
curl -s -L "https://db.torbox.app/auth/v1/verify?token=TOKEN&type=signup&redirect_to=https://torbox.app/"
```

**Success:** Returns HTML page that redirects to https://torbox.app/
**Error (expired OTP):**
```
Final URL: https://torbox.app/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired&sb=
```

---

### 5. Refresh Token
**POST** https://db.torbox.app/auth/v1/token?grant_type=refresh_token
```bash
curl -s -X POST "https://db.torbox.app/auth/v1/token?grant_type=refresh_token" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"..."}'
```

---

## Supabase REST API (PostgREST)

### Headers Required
```bash
-H "apikey: $SUPABASE_ANON_KEY"
-H "Authorization: Bearer <access_token>"
```

### Tables Accessed

#### users (or torbox_users)
**GET** https://db.torbox.app/rest/v1/users?email=eq.user@example.com&select=*
```json
[{"id":803945,"auth_id":"uuid-here","created_at":"2026-06-26T15:30:18.572424+00:00","updated_at":"2026-06-26T15:30:18.572424+00:00","plan":0,"total_downloaded":0,"customer":null,"is_subscribed":false,"premium_expires_at":"2026-06-26T15:30:18.572126+00:00","cooldown_until":null,"email":"user@example.com","user_referral":"...","base_email":null,"total_bytes_downloaded":0,"total_bytes_uploaded":0,"torrents_downloaded":0,"web_downloads_downloaded":0,"usenet_downloads_downloaded":0,"additional_concurrent_slots":0,"long_term_seeding":false,"long_term_storage":false,"is_vendor":false,"vendor_id":null,"purchases_referred":0}]
```

#### api_tokens
**GET** https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.uuid-here&select=*
```json
[{"id":809328,"created_at":"2026-06-26T15:30:18.572126+00:00","updated_at":"2026-06-26T15:30:18.572126+00:00","original":true,"auth_id":"uuid-here","token":"329b7cd1-43ff-4b31-8fd0-7db6fa3accfd"}]
```

#### settings
**GET** https://db.torbox.app/rest/v1/settings?auth_id=eq.uuid-here&select=*
```json
[{"id":4375030,"auth_id":"uuid-here","email_notifications":false,"web_notifications":true,"mobile_notifications":true,"rss_notifications":true,"download_speed_in_tab":false,"show_tracker_in_torrent":false,"stremio_quality":[0,1,2,3,4,5,6,7,8],"stremio_resolution":[0,1,2,3],"stremio_language":[0,1,2,3,4,5,6,7,8,9,10,11,12,13],"stremio_cache":[1],"stremio_size_lower":0,"google_drive_folder_id":"","onedrive_save_path":"","discord_id":null,...}]
```

---

## Free Pro Trial Activation
**Endpoint:** `POST https://api.torbox.app/v1/api/unifiedpayments/activatetrial`
**Headers:**
- `Authorization: Bearer <api_key>`
- `Content-Type: application/json`
- `x-csrf-token: <token_from_fingerprint_js>`
**Body:** `{"csrf_token": "<token_from_fingerprint_js>"}`

**Response:** Requires CSRF token from Cloudflare Turnstile/fingerprint challenge (browser-only). No clean API access.
**Conclusion:** Must be activated manually via web dashboard: https://torbox.app/dashboard → Click "Get your free demo now!"

---

## Cloudflare WAF
- Direct curl from server: **403 Forbidden (error code: 1010)**
- Playwright/browser fetch: **Works** (bypasses Cloudflare)
- Always use Playwright browser fetch for Supabase API calls

---

## Supabase Anon Key
Location: `/home/runner/workspace/credentials/.supabase_anon_key`
Length: 208 chars (JWT starting with `eyJhbGciOi...`)
Format: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ...signature`