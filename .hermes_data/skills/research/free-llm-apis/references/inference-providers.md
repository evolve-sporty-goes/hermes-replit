# Inference Providers Setup

Third-party platforms hosting open-weight models. All expose OpenAI-compatible endpoints.

---

## Cloudflare Workers AI

**Base URL:** `https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1`  
**Auth:** `Authorization: Bearer {api_token}`  
**Model field:** Use the model ID directly (e.g. `@cf/moonshotai/kimi-k2.7-code`)

### Setup Steps
1. Go to https://dash.cloudflare.com → Workers & Pages → AI
2. Note your **Account ID** (from the URL or dashboard)
3. Go to https://dash.cloudflare.com/profile/tokens
4. Create an API Token with "Workers AI" permission (read-only is fine for inference calls)
5. Set env var: `CLOUDFLARE_API_TOKEN=your_token` and `CLOUDFLARE_ACCOUNT_ID=your_account_id`

### Code Example (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["CLOUDFLARE_API_TOKEN"],
    base_url=f"https://api.cloudflare.com/client/v4/accounts/{os.environ['CLOUDFLARE_ACCOUNT_ID']}/ai/v1"
)

response = client.chat.completions.create(
    model="@cf/moonshotai/kimi-k2.7-code",
    messages=[{"role": "user", "content": "Write a Python function to merge two sorted lists."}],
    max_tokens=1024
)
print(response.choices[0].message.content)
```

### Available Free Models (coding focus)
- `@cf/moonshotai/kimi-k2.7-code` — best for code generation
- `@cf/openai/gpt-oss-120b` — strong general + code
- `@cf/qwen/qwen3-30b-a3b-fp8` — efficient code model
- `@cf/nvidia/nemotron-3-120b-a12b` — capable generalist

### Free Tier
- **10,000 neurons/day** (neurons ≈ tokens consumed; check dashboard for exact accounting)
- No credit card required
- Rate limits: undocumented but generous for personal use

### Pitfalls
- Model IDs use `@cf/` prefix — do NOT strip it or calls will fail
- Account ID is NOT the same as your Cloudflare zone ID
- Free tier only applies to Workers AI, not other Cloudflare services
- Response format is OpenAI-compatible but `system` message support varies by model

---

## Groq

**Base URL:** `https://api.groq.com/openai/v1`  
**Auth:** `Authorization: Bearer {api_key}`  
**Free models:** `llama-3.1-8b-preview`, `llama-3.3-70b-specdec`, `qwen/qwen3-32b`, `openai/gpt-oss-120b`

### Setup
1. Go to https://console.groq.com
2. Create an API key (free tier)
3. Set env var: `GROQ_API_KEY=your_key`

---

## Cerebras

**Base URL:** `https://api.cerebras.ai/v1`  
**Auth:** `Authorization: Bearer {api_key}`  
**Free models:** `gpt-oss-120b`, `llama3.1-8b`

### Setup
1. Go to https://api.cerebras.ai
2. Sign up for free tier
3. Set env var: `CEREBRAS_API_KEY=your_key`

---

## NVIDIA NIM

**Base URL:** `https://integrate.api.nvidia.com/v1`  
**Auth:** `Authorization: Bearer {api_key}`  
**Free tier:** 40 req/min with phone verification

### Setup
1. Go to https://integrate.api.nvidia.com
2. Sign up, verify phone
3. Set env var: `NVIDIA_API_KEY=your_key`

---

## GitHub Models

**Base URL:** `https://models.inference.ai.azure.com`  
**Auth:** `Authorization: Bearer {github_token}`  
**Free models:** Depends on Copilot tier (GPT-4o, DeepSeek R1, Llama 4, etc.)

### Setup
1. Requires GitHub Copilot subscription (Individual, Business, or Enterprise)
2. Use a Personal Access Token with `models:read` scope
3. Set env var: `GITHUB_TOKEN=your_pat`

---

## HuggingFace Inference

**Base URL:** `https://api-inference.huggingface.co/v1`  
**Auth:** `Authorization: Bearer {hf_token}`  
**Free tier:** $0.10/month credits; models <10GB

### Setup
1. Go to https://huggingface.co/settings/tokens
2. Create a fine-grained token with "Make calls to the Inference API"
3. Set env var: `HF_TOKEN=your_token`

---

## OpenRouter

**Base URL:** `https://openrouter.ai/api/v1`  
**Auth:** `Authorization: Bearer {api_key}`  
**Free tier:** 20 req/min, 50/day (or 1000/day after $10 topup)

### Setup
1. Go to https://openrouter.ai/keys
2. Create a key (free)
3. Set env var: `OPENROUTER_API_KEY=your_key`
