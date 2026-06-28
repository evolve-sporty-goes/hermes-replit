# Provider API Setup

Direct-from-provider APIs — run by the companies that train the models.

## Google AI Studio (Gemini)

1. Go to https://aistudio.google.com/apikey
2. Create an API key (free, no credit card)
3. Base URL: `https://generativelanguage.googleapis.com/v1beta`
4. SDK: `google-generativeai` or OpenAI-compatible with base_url

```python
from openai import OpenAI
client = OpenAI(
    api_key="GEMINI_KEY",
    base_url="https://generativelanguage.googleapis.com/v1beta/openai"
)
response = client.chat.completions.create(
    model="gemini-2.5-flash",
    messages=[{"role": "user", "content": "Hello"}]
)
```

**Limits**: 500 req/day for Gemini 2.5 Flash; 14,400/day for Gemma models. Blocked in EEA/UK/CH.

## Mistral AI (La Plateforme)

1. Go to https://console.mistral.ai/api-keys
2. Create API key (phone verification required)
3. Base URL: `https://api.mistral.ai/v1`
4. Free tier: 1 req/s, 500K tokens/min, 1B tokens/month

```python
from openai import OpenAI
client = OpenAI(api_key="MISTRAL_KEY", base_url="https://api.mistral.ai/v1")
response = client.chat.completions.create(
    model="mistral-large-latest",
    messages=[{"role": "user", "content": "Hello"}]
)
```

## Cohere

1. Go to https://dashboard.cohere.com/api-keys
2. Create API key
3. Base URL: `https://api.cohere.ai/v1` (or v2 for new models)
4. Free tier: 20 req/min, 1000/month

```python
from openai import OpenAI
client = OpenAI(api_key="COHERE_KEY", base_url="https://api.cohere.ai/v2")
response = client.chat.completions.create(
    model="command-r-plus",
    messages=[{"role": "user", "content": "Hello"}]
)
```

## Zhipu AI (GLM)

1. Go to https://open.bigmodel.cn
2. Get API key
3. Base URL: `https://open.bigmodel.cn/api/paas/v4`
4. Free tier: limited daily quota

```python
from openai import OpenAI
client = OpenAI(api_key="ZHIPU_KEY", base_url="https://open.bigmodel.cn/api/paas/v4")
response = client.chat.completions.create(
    model="glm-4-flash",
    messages=[{"role": "user", "content": "Hello"}]
)
```
