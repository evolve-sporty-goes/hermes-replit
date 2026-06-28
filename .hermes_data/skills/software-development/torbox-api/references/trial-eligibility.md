# Trial Eligibility — Confirmed Patterns

Updated 2026-06-27 from live browser testing.

## Eligibility Check Location

The `POST /v1/api/unifiedpayments/activatetrial` endpoint performs an **account-level** eligibility check AFTER the CsrfGuard PoW flow completes. It is NOT a CSRF failure or PoW failure — it is a business-logic rejection.

## Confirmed Ineligible Pattern

| Signal | Result | Evidence |
|--------|--------|----------|
| `@duck.com` email | ❌ 403 PAYMENT_ERROR | Multiple attempts, with and without SOCKS5 proxy |
| `@tempmail.com` (assumed) | ❌ Likely flagged | Pattern matches disposable domain heuristics |
| SOCKS5 proxy (different IP) | ❌ Still rejected | Rules out IP-based blocking |

## Exact Error Response (confirmed)

```json
POST /v1/api/unifiedpayments/activatetrial
Status: 403
Body: {"success":false,"error":"PAYMENT_ERROR","detail":"You are not eligible for the free trial. Please purchase a paid plan.","data":null}
```

## What Succeeds Before The Rejection

The full CsrfGuard PoW chain completes successfully for ALL accounts (even ineligible ones):
1. `GET /v1/api/csrf-token/csrf.js` → 200 (loads CsrfGuard JS)
2. `GET /v1/api/csrf-token/<challenge_id>` → 200 (returns challenge blob)
3. `POST /v1/api/csrf-token/?ci=js/4.1.1&q=<challenge>` → 200 (returns valid `sealed_result`)
4. `POST /v1/api/unifiedpayments/activatetrial` → **403** (rejected at business logic layer)

This means the trial button click always "succeeds" from the UI perspective (no error shown to user), but the API rejects at step 4.

## Diagnostic Steps

1. Click "Get your free demo now!" in browser
2. Inject fetch interceptor BEFORE clicking (see `references/csrf-guard-flow.md`)
3. Wait 5 seconds, read `window.__captured`
4. Check the `activatetrial` entry's status code and body
5. If 403 → account not eligible (email domain or other signal)
6. If 500 → TorBox server bug, retry later
7. If 200 → success, verify via `/user/me` (plan should be 1)

## Recommendation

Use a non-disposable email (Gmail, Outlook, corporate domain) when creating TorBox accounts intended for the free trial. Disposable domains are flagged at the account level and cannot be circumvented by using a different IP. Do NOT use Tor or any VPN/proxy — use a clean residential IP.

## VPN/Proxy Blocking on Signup & Payment

TorBox **actively blocks VPNs and proxies** on signup and payment flows. From their official support docs ([source](https://support.torbox.app/en/articles/14013985-i-get-an-error-when-subscribing)):

- **Error message:** `"We're sorry, but we are unable to process payments from your IP address at this time. Please disable any VPNs including iCloud Relay. Please try again later."`
- **Also blocks:** iCloud Relay, Brave browser VPN, SOCKS5 proxies, Tor exit nodes
- **Workarounds they suggest:** switch to mobile data, switch devices, clear cookies, disable incognito mode, wait 24h between attempts
- **Rate limit:** Max 5 checkout attempts per hour

**Implication for Tor SOCKS5 proxy:** Using Tor for signup will almost certainly fail — Tor exit nodes are flagged as proxy/VPN traffic. Even if the Supabase auth signup (`POST /auth/v1/signup`) succeeds (it's more permissive), the subsequent dashboard/subscription flow will block Tor IPs.

**Confirmed 2026-06-28:** User asked about using Tor SOCKS5 proxy for signup. Answer: technically possible for the Supabase auth call, but TorBox's fraud detection will block it on any payment/subscription action. Not recommended.

**Confirmed 2026-06-28 (follow-up):** Actually attempted `curl --socks5-hostname 127.0.0.1:9050` to `https://db.torbox.app/auth/v1/signup` — the response was a full Cloudflare "Just a moment..." JS challenge HTML page (not a 403 or 429). This means Tor exit nodes are blocked at the Cloudflare WAF layer with a JS challenge that `curl` cannot solve. Tor is not viable for **any** TorBox operation (signup, verify, or API calls to `db.torbox.app`).
