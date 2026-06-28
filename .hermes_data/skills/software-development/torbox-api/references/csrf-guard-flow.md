# CsrfGuard Flow — Captured from TorBox Browser Session

Complete request/response chain for the `activatetrial` endpoint, captured via
`window.fetch` interception in `browser_console` on 2026-06-26.

## Flow Sequence

### Step 1: Load CsrfGuard JS
```
GET https://api.torbox.app/v1/api/csrf-token/csrf.js
Status: 200
Body: ~180KB JavaScript (CsrfGuard client library)
```

### Step 2: Fetch Challenge
```
GET https://api.torbox.app/v1/api/csrf-token/GBq9/f4o7fc/2?q=xVe4iNm6GPPhNe995ryt
Status: 200
Body: Base64-encoded encrypted challenge blob (e.g. "QlYJKAAvT/NUvbdFlE/...")
```

The path segment `GBq9/f4o7fc/2` and query `q=xVe4iNm6GPPhNe995ryt` appear to be
static per-site constants (same across multiple sessions). The CsrfGuard JS reads
these and processes the challenge blob client-side.

### Step 3: Solve PoW and Get Sealed CSRF Token
```
POST https://api.torbox.app/v1/api/csrf-token/?ci=js/4.1.1&q=xVe4iNm6GPPhNe995ryt
Content-Type: text/plain
Body: <processed challenge output from JS runtime>
Status: 200
Body: {
  "version": "4",
  "event_id": "1782515838498.a6Vkv7",
  "sealed_result": "noXc7Qp+MVniIcGfiTAu1W6EWwA19BOP..."  // ~300 chars base64
}
```

**The `sealed_result` IS the `csrf_token`** — pass it directly in the
activatetrial request body.

#### Curl Failure
Attempting step 2+3 via curl (without the JS runtime) fails:
```json
{"version":"4","event_id":"...","sealed_result":null,
 "error":{"code":"request_cannot_be_parsed","message":"bad request"}}
```
The challenge blob must be decoded/processed by the CsrfGuard JS before posting back.
Curl cannot do this — only the browser can.

### Step 4: Activate Trial
```
POST https://api.torbox.app/v1/api/unifiedpayments/activatetrial
Authorization: Bearer <supabase_access_token>
Content-Type: application/json
Body: {"csrf_token": "<sealed_result from step 3>"}
```

Possible responses:
- `200` + `{"success": true}` — trial activated, plan changes to 1 (Pro)
- `403` + `{"success":false,"error":"PAYMENT_ERROR","detail":"You are not eligible for the free trial. Please purchase a paid plan."}` — **confirmed 2026-06-27**: disposable email domains (e.g. `@duck.com`) are flagged. The full CsrfGuard PoW chain completes successfully (steps 1-3 return valid `sealed_result`), but `activatetrial` rejects at step 4 with this 403. Use a non-disposable email (Gmail, Outlook) for trial eligibility.
- `500` + `{"success":false,"error":"UNKNOWN_ERROR","detail":"...NoneType..."}` — TorBox backend bug (Python NoneType crash)

**Confirmed 2026-06-27:** The full CsrfGuard chain (steps 1-3) succeeds for ALL accounts — even ineligible ones. The rejection happens at step 4 (`activatetrial`) as a business-logic check, NOT as a CSRF/PoW failure.

## How to Capture This Flow

Before clicking the trial button in the browser, inject fetch interceptors:

```javascript
window.__captured = [];
const origFetch = window.fetch;
window.fetch = async function(...args) {
  const url = typeof args[0] === 'string' ? args[0] : args[0]?.url;
  const opts = args[1] || {};
  const resp = await origFetch.apply(this, args);

  if (url.includes('activatetrial') || url.includes('csrf-token')) {
    const clone = resp.clone();
    let body = '';
    try { body = await clone.text(); } catch(e) { body = 'unreadable'; }

    let sentBody = null;
    if (opts.body && typeof opts.body === 'string') sentBody = opts.body.substring(0,500);

    window.__captured.push({
      url: url.replace('https://api.torbox.app/v1/api', ''),
      method: opts.method || 'GET',
      status: resp.status,
      sent_body: sentBody,
      response: body.substring(0,500)
    });
  }
  return resp;
};
```

Then click the button, wait 5-6 seconds, and read `window.__captured`.
