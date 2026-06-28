"""
flaresolverr_session.py — Persistent FlareSolverr session that auto-bypasses Cloudflare.
All requests share the same browser context, so CF cookies are reused across calls.

Usage:
    from flaresolverr_session import FlareSolverrSession

    session = FlareSolverrSession(proxy="socks5://127.0.0.1:9050")

    # GET — CF solved automatically, cookies kept
    resp = session.get("https://db.torbox.app/auth/v1/signup")

    # POST — reuses CF cookies from previous call, no re-challenge
    resp = session.post("https://db.torbox.app/auth/v1/signup",
                        json={"email": "test@proton.me", "password": "..."})

    # Any subsequent request to same domain — zero CF overhead
    resp = session.get("https://db.torbox.app/v1/api/user/me",
                       headers={"Authorization": "Bearer <token>"})
"""

import json
import requests


class FlareSolverrSession:
    """Drop-in replacement for requests.Session that routes through FlareSolverr."""

    def __init__(self, fs_url="http://127.0.0.1:8191/v1", proxy=None, max_timeout=120000):
        self.fs_url = fs_url
        self.proxy = proxy
        self.max_timeout = max_timeout
        self.cookies = {}  # domain -> {name: cookie_dict}
        self.user_agent = None

    def _merge_cookies(self, domain, new_cookies):
        """Merge new cookies into persistent store."""
        if domain not in self.cookies:
            self.cookies[domain] = {}
        for c in new_cookies:
            self.cookies[domain][c["name"]] = c

    def _get_cookies_for_domain(self, domain):
        """Get all cookies for a domain (including parent domains)."""
        result = []
        for d, cdict in self.cookies.items():
            if domain.endswith(d) or d.endswith(domain):
                result.extend(cdict.values())
        return result

    def _call_fs(self, cmd, url, headers=None, post_data=None):
        """Send request to FlareSolverr."""
        payload = {
            "cmd": cmd,
            "url": url,
            "maxTimeout": self.max_timeout,
        }
        if self.proxy:
            payload["proxy"] = {"url": self.proxy}

        # Inject existing CF cookies
        from urllib.parse import urlparse
        domain = urlparse(url).hostname
        existing = self._get_cookies_for_domain(domain)
        if existing:
            payload["cookies"] = existing

        # Inject headers
        if headers:
            payload["headers"] = {k: v for k, v in headers.items()}

        # POST data
        if post_data is not None:
            payload["postData"] = post_data

        resp = requests.post(self.fs_url, json=payload, timeout=self.max_timeout / 1000 + 10)
        data = resp.json()

        if data.get("status") == "ok":
            solution = data.get("solution", {})
            # Save cookies for future requests
            resp_cookies = solution.get("cookies", [])
            self._merge_cookies(domain, resp_cookies)
            # Save user-agent
            if solution.get("userAgent"):
                self.user_agent = solution["userAgent"]
            return solution.get("response", ""), solution
        else:
            raise RuntimeError(f"FlareSolverr error: {data.get('message', 'unknown')}")

    def get(self, url, headers=None):
        """GET request through FlareSolverr. CF solved automatically."""
        return self._call_fs("request.get", url, headers=headers)

    def post(self, url, json=None, data=None, headers=None):
        """POST request through FlareSolverr. Reuses CF cookies."""
        post_data = json if json else data
        return self._call_fs("request.post", url, headers=headers, post_data=post_data)

    def clear_cookies(self, domain=None):
        """Clear stored cookies (or just for one domain)."""
        if domain:
            self.cookies.pop(domain, None)
        else:
            self.cookies.clear()


if __name__ == "__main__":
    import sys

    session = FlareSolverrSession(proxy="socks5://127.0.0.1:9050")

    if len(sys.argv) < 3:
        print("Usage: python flaresolverr_session.py <get|post> <url> [json_body]")
        sys.exit(1)

    method, url = sys.argv[1], sys.argv[2]
    if method == "get":
        body, sol = session.get(url)
    elif method == "post":
        body_data = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        body, sol = session.post(url, json=body_data)
    else:
        print("Method must be get or post")
        sys.exit(1)

    print(body)
