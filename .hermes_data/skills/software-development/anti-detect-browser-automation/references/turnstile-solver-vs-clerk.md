# Turnstile Solver vs Clerk-Managed Turnstile

## Problem

The self-hosted `icemellow-me/turnstile-solver` (nodriver + camoufox engines)
returns `ERROR_CAPTCHA_UNSOLVABLE` when targeting Cloudflare Turnstile challenges
managed by Clerk.js (OpenRouter, Firecrawl, etc.).

## Root Cause

Clerk's `captchaWidgetType: "smart"` mode uses Cloudflare's managed/invisible
Turnstile which performs aggressive bot detection. The nodriver (CDP Chromium) and
camoufox (Firefox) engines in the solver lack the stealth patches needed to pass
Cloudflare's bot scoring for this challenge type.

**Confirmed failure (2026-07-01):**
```
sitekey: 0x4AAAAAAAWXJGBD7bONzLBd
pageurl: https://openrouter.ai/sign-up
result: ERROR_CAPTCHA_UNSOLVABLE (after ~90s, both engines exhausted)
```

The solver works fine on standalone/demo Turnstile widgets
(`demo.turnstile.workers.dev`) where bot detection is minimal.

## Solution

**Do NOT use the turnstile-solver for Clerk-managed signup flows.** Instead:

1. Use CloakBrowser (`launch_persistent_context` with `DISPLAY=:1`, `headless=False`,
   `humanize=True`) which has 58+ C++ stealth patches that pass Cloudflare bot detection.
2. Fill the Clerk form using `type()` + React fiber `onChange` for checkbox (see
   `clerkjs-form-debugging.md`).
3. Click Continue — Clerk validates React state, renders Turnstile.
4. CloakBrowser auto-solves the challenge (or user clicks it manually on display 1).

## When to use turnstile-solver

| Scenario | Tool |
|----------|------|
| Standalone Turnstile widget (non-Clerk) | ✅ turnstile-solver works |
| Demo sites (turnstile.workers.dev) | ✅ turnstile-solver works |
| Clerk-managed Turnstile (OpenRouter, Firecrawl) | ❌ Use CloakBrowser instead |
| Need raw token for API call | ⚠️ Only if solver can solve it |

## Architecture note

The turnstile-solver is still useful as a 2captcha-compatible API replacement
for tools that speak the 2captcha protocol. But for signup automation flows
involving Clerk.js, CloakBrowser's stealth Chromium is the only reliable path.
