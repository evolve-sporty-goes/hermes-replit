# Cloudflare Workers AI — Model Catalog Detail

Condensed from OpenRouter's Cloudflare provider page (2026-06). Cloudflare hosts
13 text models spanning 1B to 284B+ parameters. All free at 10,000 neurons/day.

## Full Model Catalog (text, coding-focused)

| Model ID | Released | Context | Input $/M | Output $/M | Params | Best for |
|---|---|---|---|---|---|---|
| `cf/moonshotai/kimi-k2.7-code` | 2026-06-12 | 262K | $0.95 | $4.00 | 1T total / 32B act | Long-horizon coding, agentic decomposition |
| `cf/zai-org/glm-5.2` | 2026-06-16 | 1.05M | $1.40 | $4.40 | — | Project-level SWE, multi-step automation, largest context |
| `cf/moonshotai/kimi-k2.6` | 2026-04-20 | 262K | $0.95 | $4.00 | — | Coding-driven UI gen, multi-agent orchestration |
| `cf/deepseek/deepseek-v4-flash` | 2026-04-23 | 1.05M | $0.14 | $0.28 | 284B / 13B act | Most cost-efficient, high-throughput coding |
| `cf/google/gemma-4-26b-a4b-it` | 2026-04-03 | 262K | $0.10 | $0.30 | 25.2B / 3.8B act | Near-31B quality at fraction of cost, Apache 2.0 |
| `cf/zai-org/glm-4.7-flash` | 2026-01-19 | 200K | $0.0605 | $0.40 | 30B-class | Cheapest input, agentic coding, SOTA at size |
| `cf/mistral/mistral-small-3-1-24b` | 2025-03-17 | 128K | $0.351 | $0.555 | 24B | Multimodal, multilingual, privacy-sensitive |
| `cf/meta-llama/llama-3.3-70b-instruct` | 2024-12-06 | 131K | $0.293 | $2.253 | 70B | Multilingual dialogue |
| `cf/ibm-granite/granite-4.0-h-micro` | 2025-10-19 | 8K | $0.017 | $0.112 | 3B | Smallest, lowest pricing, long-context tool calling |

## Recommendation by Budget

| Budget | Best Model | Why |
|---|---|---|
| **Free / zero budget** | `cf/zai-org/glm-4.7-flash` | $0.06/M input, strong coding at 30B |
| **Best quality regardless of cost** | `cf/zai-org/glm-5.2` | 1M context, newest, built for agentic SWE |
| **Best free coding specialist** | `cf/moonshotai/kimi-k2.7-code` | Purpose-built for code, thinking mode always on |
| **Best free value (general + code)** | `cf/deepseek/deepseek-v4-flash` | $0.14/M input, 1M context, MoE efficiency |

## Key Quirks

- Model IDs use `cf/` prefix on OpenRouter (NOT `@cf/` — that's for Cloudflare's own API)
- `@cf/` prefix is required when calling Cloudflare's direct API (`api.cloudflare.com/.../ai/v1`)
- On OpenRouter, the same model is `cf/moonshotai/kimi-k2.7-code` (no `@`)
- GLM 5.2 supports `xhigh` reasoning effort (maps to max reasoning)
- Kimi K2.7 Code always operates in thinking mode — cannot disable it
- DeepSeek V4 Flash uses hybrid attention for efficient 1M context processing
