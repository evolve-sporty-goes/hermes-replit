# Cloudflare Workers AI Provider for Hermes

## Overview

Cloudflare Workers AI exposes models via two distinct API formats. Both work with Hermes, but they require different config shapes. Picking the wrong config is the #1 source of setup mistakes.

## Format 1 — OpenAI-Compatible Chat Completions (recommended for Hermes)

Cloudflare maintains an OpenAI-compatible `/v1/chat/completions` endpoint on top of Workers AI. This is what Hermes uses.

**Endpoint:**
```
POST https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1/chat/completions
Authorization: Bearer {API_KEY}
```

**Config shape** (legacy top-level section — works without moving to `providers:`):
```yaml
cloudflare:
  apiKey: <your-cloudflare-api-key>        # also read from CLOUDFLARE_API_KEY env var
  accountId: <your-cloudflare-account-id>  # used only for documentation; URL is what matters
  model: '@cf/moonshotai/kimi-k2.7-code'
  active_model: '@cf/moonshotai/kimi-k2.7-code'
  api_base: https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1
```

**Key points:**
- `api_base` must end at `/ai/v1` — Hermes appends `/chat/completions` automatically.
- `apiKey` is sent as `Authorization: Bearer {apiKey}`.
- Do NOT append `/chat/completions` to `api_base` — that would double up and 404.
- `accountId` in the config is informational; the actual account is embedded in `api_base`.
  Hermes does not auto-construct the URL from `accountId` — `api_base` is required.

## Format 2 — Native Workers AI Binding API

Cloudflare's native API embeds the model in the URL path. This format is used by Workers, the Python `requests` example, and the `curl` example in Cloudflare docs:

```
POST https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/run/@cf/moonshotai/kimi-k2.7-code
Authorization: Bearer {API_KEY}
{ "messages": [...] }
```

**Hermes does NOT support Format 2.** There is no Hermes provider code that builds URLs from `ai/run/{model}`. Trying to set `api_base` to the `/ai/run/...` path will fail because Hermes still appends `/chat/completions`, producing a broken URL like `/ai/run/@cf/moonshotai/kimi-k2.7-code/chat/completions`.

If you need Format 2 (e.g. custom integration), use a reverse proxy that translates OpenAI-compatible requests to the `ai/run/` format, or implement it as an MCP server.

## Config Pitfall — Do NOT Blank `api_base`

The Hermes legacy custom-provider normalizer (`hermes_cli/config.py::_normalize_custom_provider_entry`) requires a valid `base_url` (which comes from `api_base`). If `api_base` is empty or blank, the function returns `None` and the provider is silently skipped — no error, no warning, the model just won't appear.

If you're trying to "use account ID instead of base URL," that won't work. Set `api_base` to the full OpenAI-compatible URL using your account ID. There is no auto-construction from `accountId` in Hermes.

## Available Models

Model IDs use the `@cf/{provider}/{model}` format:
- `@cf/moonshotai/kimi-k2.7-code` — 1T param, 262k context, tool calling, vision
- `@cf/meta/llama-3.1-8b-instruct`
- `@cf/openai/gpt-oss-120b`
- Full list: https://developers.cloudflare.com/workers-ai/models/

## Docs

- https://developers.cloudflare.com/workers-ai/
- https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/
- https://developers.cloudflare.com/workers-ai/models/kimi-k2.7-code/
