---
name: free-llm-api-resources
description: "Free LLM API providers, models, and rate limits — curated list from cheahjs/free-llm-api-resources. Use when looking for free API keys, comparing provider quotas, or finding a no-cost model for a task."
version: 1.0.0
author: cheahjs (https://github.com/cheahjs/free-llm-api-resources)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [llm, api, free, providers, models, rate-limits]
    homepage: https://github.com/cheahjs/free-llm-api-resources
---

# Free LLM API Resources

Curated list of services providing free access or credits towards API-based LLM usage.

> [!NOTE]
> Please don't abuse these services, else we might lose them.

> [!WARNING]
> This list explicitly excludes any services that are not legitimate (eg reverse engineers an existing chatbot).

Source: https://github.com/cheahjs/free-llm-api-resources

## When to use this skill

- User needs a free LLM API key or provider
- Comparing rate limits / quotas across providers
- Looking for a specific model available for free
- Setting up auxiliary models (vision, STT, TTS) on a budget
- Finding trial credits for a short-term project

## Provider Quick Reference

### Free Providers

| Provider | Free Quota | Auth | Notes |
|----------|-----------|------|-------|
| **OpenRouter** | 20 req/min, 50/day ($10 topup → 1000/day) | API key | Models share quota. Many frontier models free. |
| **Google AI Studio** | 20-500 req/day depending on model | API key | Data used for training outside UK/CH/EEA/EU |
| **NVIDIA NIM** | 40 req/min | Phone verification | Context window limited |
| **Mistral (La Plateforme)** | 1 req/s, 500K tokens/min, 1B tokens/month | Phone verification | Opt into data training |
| **Mistral (Codestral)** | 30 req/min, 2000/day | Phone verification | Monthly subscription based |
| **HuggingFace Inference** | $0.10/month credits | Token | Models <10GB (some exceptions) |
| **Vercel AI Gateway** | $5/month | API key | Routes to various providers |
| **OpenCode Zen** | Free tier | API key | May use data for improvement |
| **Cerebras** | 30 req/min, 14,400/day | API key | gpt-oss-120b, Llama 3.1 8B |
| **Groq** | Up to 14,400 req/day | API key | Fast inference, many models |
| **Cohere** | 20 req/min, 1000/month | API key | Models share monthly quota |
| **GitHub Models** | Varies by Copilot tier | GitHub token | Very restrictive token limits |
| **Cloudflare Workers AI** | 10,000 neurons/day | API key | Includes Kimi K2.6/K2.7-code |

### Providers with Trial Credits

| Provider | Credits | Key Models |
|----------|---------|------------|
| **Fireworks** | $1 | Various open models |
| **Baseten** | $30 | Any supported model |
| **Nebius** | $1 | Various open models |
| **Novita** | $0.50 for 1 year | Various open models |
| **AI21** | $10 for 3 months | Jamba family |
| **Upstage** | $10 for 3 months | Solar Pro/Mini |
| **NLP Cloud** | $15 | Various open models |
| **Alibaba Cloud Model Studio** | 1M tokens/model | Qwen models |
| **Modal** | $5/mo ($30 with payment) | Any supported model |
| **Inference.net** | $1 ($25 with survey) | Various open models |
| **Hyperbolic** | $1 | DeepSeek V3, Llama 3.3, Qwen3 Coder |
| **SambaNova Cloud** | $5 for 3 months | DeepSeek, Gemma, GPT-oss, Llama, MiniMax |
| **Scaleway** | 1M free tokens | Gemma, Llama, Mistral, Qwen, Whisper |

## Notable Free Models by Provider

### OpenRouter (full model IDs)
- `nousresearch/hermes-3-llama-3.1-405b:free`
- `meta-llama/llama-3.2-3b-instruct:free`
- `meta-llama/llama-3.3-70b-instruct:free`
- `google/gemma-4-26b-a4b-it:free`
- `google/gemma-4-31b-it:free`
- `nvidia/nemotron-3-super-120b-a12b:free`
- `nvidia/nemotron-3-ultra-550b-a55b:free`
- `openai/gpt-oss-120b:free`
- `openai/gpt-oss-20b:free`
- `qwen/qwen3-coder:free`
- `qwen/qwen3-next-80b-a3b-instruct:free`
- `liquid/lfm-2.5-1.2b-instruct:free`
- `liquid/lfm-2.5-1.2b-thinking:free`
- `poolside/laguna-m.1:free`
- `cohere/north-mini-code:free`
- `cognitivecomputations/dolphin-mistral-24b-venice-edition:free`

### Cloudflare Workers AI (model IDs)
- `@cf/moonshotai/kimi-k2.6`
- `@cf/moonshotai/kimi-k2.7-code`
- `@cf/nvidia/nemotron-3-120b-a12b`
- `@cf/openai/gpt-oss-120b`
- `@cf/openai/gpt-oss-20b`
- `@cf/qwen/qwen3-30b-a3b-fp8`
- `@cf/zai-org/glm-4.7-flash`
- `@cf/zai-org/glm-5.2`
- `@cf/google/gemma-4-26b-a4b-it`
- `@cf/ibm-granite/granite-4.0-h-micro`
- Llama 3.1/3.2/3.3/4, Mistral 7B/Small 3.1, Qwen 2.5 Coder/QwQ

### Google AI Studio
- Gemini 3.5 Flash, 3 Flash, 3.1 Flash-Lite (500 req/day), 2.5 Flash/Lite
- Gemma 3 1B/4B/12B/27B Instruct (14,400 req/day each)

### Groq
- Llama 3.1 8B (14,400/day), Llama 3.3 70B (1,000/day)
- gpt-oss-120b (1,000/day), qwen/qwen3-32b (1,000/day)
- groq/compound (250/day, 70K tokens/min)

### Cerebras
- gpt-oss-120b, Llama 3.1 8B — 30 req/min, 14,400/day, 1M tokens/day

### GitHub Models
- GPT-5/4.1/4o, o1/o3/o4-mini, DeepSeek R1/V3, Llama 4, Mistral, Phi-4
- Rate limits depend on Copilot subscription tier

## Best Model by Use Case

### Coding / Code Generation
| Provider | Best coding model | Why |
|---|---|---|
| **Cloudflare** | `@cf/moonshotai/kimi-k2.7-code` | Purpose-built for code; top performer on Cloudflare |
| **OpenRouter** | `deepseek/deepseek-r1-0528:free` or `qwen/qwen3-coder:free` | Strong reasoning + code-specific tuning |
| **Groq** | `qwen/qwen3-32b` | Fast inference, good code quality |
| **Cerebras** | `gpt-oss-120b` | Large open-weight model, capable at code |
| **GitHub Models** | `deepseek/deepseek-r1` or `openai/gpt-4.1` | Depends on Copilot tier |

### General Chat / Multi-purpose
| Provider | Best general model | Why |
|---|---|---|
| **OpenRouter** | `nvidia/nemotron-3-super-120b-a12b:free` | Strong all-rounder, free |
| **Google AI Studio** | `gemini-2.5-flash` | Excellent quality, generous free tier |
| **Cloudflare** | `@cf/openai/gpt-oss-120b` | OpenAI quality, no signup friction |
| **Groq** | `llama-3.3-70b` | Good balance of speed and quality |

### Reasoning / Complex Tasks
| Provider | Best reasoning model | Why |
|---|---|---|
| **OpenRouter** | `openai/gpt-oss-120b:free` | Strong reasoning, free |
| **Cloudflare** | `@cf/openai/gpt-oss-120b` | Same model, direct access |
| **Cerebras** | `gpt-oss-120b` | High throughput reasoning |

### Fastest Inference
| Provider | Model | Notes |
|---|---|---|
| **Groq** | Llama 3.1 8B / qwen3-32b | ~100 tokens/sec |
| **Cerebras** | Llama 3.1 8B | Optimized for speed |
| **Cloudflare** | `@cf/moonshotai/kimi-k2.7-code` | Fast for code specifically |

## Best for Coding

Ranked by code quality among free-tier models:

| Rank | Provider | Model | Why |
|------|----------|-------|-----|
| 1 | Cloudflare | `@cf/moonshotai/kimi-k2.7-code` | Purpose-built for code; strong at generation, debugging, refactoring |
| 2 | OpenRouter | `deepseek/deepseek-r1` / `qwen/qwen3-coder` | DeepSeek R1 for complex reasoning, Qwen3 Coder for fast iteration |
| 3 | Google AI Studio | `gemini-2.5-flash` | Good instruction following, large context |
| 4 | Groq | `qwen/qwen3-32b` | Fast inference, decent code quality |
| 5 | Cerebras | `gpt-oss-120b` | OpenAI-compatible, solid generalist |

**Recommendation:** For pure coding tasks, start with Cloudflare's Kimi K2.7-code. It's free, fast, and specifically trained for code. If you need more reasoning depth (e.g. complex architecture or debugging), fall back to DeepSeek R1 on OpenRouter.

## Largest Free Models (by parameter count)

| Model | Provider | Params | Active (MoE) | Free tier limit |
|---|---|---|---|---|
| `nvidia/nemotron-3-ultra-550b-a55b:free` | OpenRouter | 550B | 55B | 50 req/day |
| `nousresearch/hermes-3-llama-3.1-405b:free` | OpenRouter | 405B | — | 50 req/day |
| `nvidia/nemotron-3-super-120b-a12b:free` | OpenRouter | 120B | 12B | 50 req/day |
| `openai/gpt-oss-120b:free` | OpenRouter | 120B | MoE | 50 req/day |
| `@cf/openai/gpt-oss-120b` | Cloudflare | 120B | MoE | 10K neurons/day |
| `@cf/nvidia/nemotron-3-120b-a12b` | Cloudflare | 120B | 12B | 10K neurons/day |

**Pitfall:** On OpenRouter, always append `:free` to the model ID. Without it, OpenRouter routes to the paid variant and charges your account.

## Tips

- **OpenRouter** is the best starting point — widest selection of free frontier models.
- **Google AI Studio** gives the highest request counts for Gemma models (14,400/day).
- **Cloudflare Workers AI** has Kimi K2.7-code which is the best free coding model available.
- **Cerebras** and **Groq** offer high throughput for their free models.
- For **STT/TTS**: Groq has free Whisper Large v3; Google AI Studio has Gemini TTS.
- Always check the source repo for updates — free tiers change frequently.
- To set a free model in Hermes: `hermes config set model.default 'provider/model:free'` then verify with `hermes config` and `hermes doctor`.

## Cloudflare Model Deep-Dive

For a full breakdown of all 13 Cloudflare-hosted text models (pricing, context windows, use-case rankings), see [`references/cloudflare-workers-ai-models.md`](references/cloudflare-workers-ai-models.md).
