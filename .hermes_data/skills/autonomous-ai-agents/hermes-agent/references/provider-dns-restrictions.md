# Provider DNS Restrictions on Restricted Networks

Some sandboxed environments (notably **Replit Nix**) have DNS whitelists that block
resolution of certain provider subdomains while allowing the main domain.

## HuggingFace Inference API

Observed on Replit (June 2026):

- `huggingface.co` resolves fine (IPv4 reachable).
- `router.huggingface.co` resolves fine.
- `api-inference.huggingface.co` does **not** resolve (NXDOMAIN / "Could not resolve host").

This means `HF_TOKEN` alone is NOT sufficient. Hermes will repeatedly fail with
`APIConnectionError` / `Connection error` and exhaust retries.

### Workarounds

1. **Use Hugging Face provider proxied through OpenRouter** — Set provider to `huggingface` but override `base_url` to OpenRouter's endpoint. This keeps the HF provider identity while routing traffic through the reachable OpenRouter host:
   ```
   hermes config set model.provider huggingface
   hermes config set model.default <hf-model-id>
   hermes config set model.base_url https://openrouter.ai/api/v1
   ```
   Requires `OPENROUTER_API_KEY` in `.env`. The model ID can be any HF model available on OpenRouter (e.g. `huggingfaceh4/zephyr-141b-a35b`, `qwen/qwen3-coder`).

2. **Use OpenRouter as the provider directly** — Simpler but loses the HF provider label. Set provider to `openrouter` and use the OpenRouter-prefixed model ID:
   ```
   hermes config set model.provider openrouter
   hermes config set model.default openrouter/meta-llama/llama-3.1-8b-instruct
   hermes config set model.base_url https://openrouter.ai/api/v1
   ```

2. **Use a custom OpenAI-compatible endpoint** — If you have a working endpoint (e.g. a self-hosted proxy, llama.cpp on a reachable host), set `model.base_url` + `model.api_key` directly in config.yaml.

3. **Try other providers** — In order of reliability on restricted networks: OpenRouter → Anthropic → OpenAI → DeepSeek → Google. All use common CDN domains that typical whitelists allow.

### Diagnostic Recipe

When a provider fails with `APIConnectionError` before any HTTP exchange:

```bash
# 1. Check DNS resolution
getent hosts api-inference.huggingface.co        # fails = DNS block
getent hosts huggingface.co                     # works = selective whitelist

# 2. Check connectivity (even if DNS works)
curl -s -o /dev/null -w "%{http_code}" https://<provider-endpoint>/health

# 3. Check env vars are present
env | grep -i "API_KEY\|TOKEN"
```

### Root Cause

The Replit Nix sandbox uses a package-firewall (`GOPROXY=http://package-firewall.replit.local/go/`)
and a custom DNS resolver (`nameserver 172.24.0.254`) that only whitelists apex domains
for popular services. Subdomains like `api-inference` are not included.

### Model

This is an environment-level restriction, not a HF-account or Hermes-config issue.
Do not spend time debugging auth/token/config — jump straight to the DNS check.
