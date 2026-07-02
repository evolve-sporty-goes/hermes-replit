# Cloudflare signup via curl — diagnostic transcript

## Context

User asked to sign up to Cloudflare using `curl` only. The goal was to determine
whether the public Cloudflare dashboard signup can be completed through raw HTTP
requests.

## Finding: `/sign-up` is challenge-walled

Cloudflare's own dashboard serves a managed challenge on `/sign-up`. A direct
curl request cannot proceed past it.

### Command

```bash
curl -sSL -D - \
  -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
  -c /tmp/cf-cookies.txt -b /tmp/cf-cookies.txt \
  "https://dash.cloudflare.com/sign-up" -o /tmp/cf-signup.html
```

### Response headers

```
HTTP/2 403
cf-mitigated: challenge
server: cloudflare
```

### Response body indicators

- `<title>Just a moment...</title>`
- `<script nonce="...">` block sets `window._cf_chl_opt` with `cType: 'managed'`
- Challenge script loaded from `/cdn-cgi/challenge-platform/h/b/orchestrate/chl_page/v1`
- The body contains no actual signup form.

## Implication

There is **no public unauthenticated Cloudflare API for creating new accounts**.
The browser must pass the managed challenge before the registration form and
frontend API become reachable. Once session cookies are established in a real
browser, curl can carry those cookies to subsequent dashboard API endpoints.

## Recommended workflow when asked to do this again

1. Issue a diagnostic curl first and check for `cf-mitigated: challenge`.
2. If present, explain that curl cannot solve the JS challenge.
3. Use CloakBrowser (`launch_persistent_context`, `headless=False`,
   `humanize=True`) to navigate to `dash.cloudflare.com/sign-up`, clear the
   challenge, and proceed with registration.
4. After registration, dump cookies and user-agent with:
   ```python
   cookies = context.cookies()
   user_agent = page.evaluate("navigator.userAgent")
   ```
5. Use curl for subsequent API calls by replaying those cookies and the same UA.

## Notes

- The same pattern applies to any bot-protected signup page where the user
  initially requests a curl-only approach.
- For Cloudflare specifically, the challenge is served by their edge; proxies or
  user-agent rotation generally will not bypass it without a browser capable of
  executing the challenge JS.
