# TorBox Supabase Table Structure

Discovered by querying the Supabase REST API at `https://db.torbox.app/rest/v1/` with anon key + user JWT.

## Tables with useful data

### `users`
- Primary key: `id` (bigint, e.g. 803945)
- Also has `auth_id` (uuid, links to Supabase auth)
- Fields from `/user/me`: `id`, `auth_id`, `created_at`, `updated_at`, `plan` (0=free, 1=pro), `total_downloaded`, `customer`, `is_subscribed`, `premium_expires_at`, `cooldown_until`, `email`, `user_referral`, `base_email`, `total_bytes_downloaded`, `total_bytes_uploaded`, `torrents_downloaded`, `web_downloads_downloaded`, `usenet_downloads_downloaded`, `additional_concurrent_slots`, `long_term_seeding`, `long_term_storage`, `is_vendor`, `vendor_id`, `purchases_referred`
- Query: `GET /rest/v1/users?email=eq.<email>&select=*`

### `api_tokens`
- Primary key: `id` (bigint)
- Foreign key: `auth_id` (uuid, links to users)
- Fields: `token` (the actual TorBox API key, 36 chars UUID format), `original` (boolean), `created_at`, `updated_at`
- Query: `GET /rest/v1/api_tokens?auth_id=eq.<uuid>&select=token`
- **This is how you get the TorBox API key without the web UI**

### `settings`
- Foreign key: `auth_id` (uuid)
- Fields: notification preferences, stremio settings, google_drive_folder_id, discord_id, etc.
- No API key here.

### `torbox_users`
- Does NOT exist (returns "relation does not exist")

### `accounts`
- Does NOT exist or uses different ID scheme

### `subscriptions`
- Exists but requires elevated privileges (returns "permission denied for table subscriptions")

## Auth flow summary

1. Login: `POST /auth/v1/token?grant_type=password` → get `access_token`
2. Use token as `Authorization: Bearer` on all REST queries
3. Anon key goes in `apikey: *** header
4. Both needed for RLS to allow access to `api_tokens` and `users` tables

## Example one-liner

```bash
# After logging in and having TOKEN and SUPABASE_KEY:
curl -s "https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.<auth_id>&select=token" \
  -H "apikey: $SUPAB... \
  -H "Authorization: Bearer $TOKEN...# Returns: [{"id":809328,"token":"329b7c...ccfd"}]
```
