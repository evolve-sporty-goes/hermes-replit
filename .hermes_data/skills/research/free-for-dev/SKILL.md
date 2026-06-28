---
name: free-for-dev
description: "Curated reference of free-tier SaaS, PaaS, IaaS, and developer tools — cloud providers, APIs, CI/CD, databases, monitoring, auth, email, and more. Use when selecting free-tier services for a project or checking what free tier a provider offers."
version: 1.0.0
source: https://github.com/ripienaar/free-for-dev
author: ripienaar + 1600+ contributors
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [free-tier, cloud, devops, saas, paas, iaas, reference, tools]
---

# Free-for.dev — Free Developer Tools & Services Reference

A curated list of SaaS, PaaS, IaaS, and other offerings with **free tiers** relevant to devops and infradev. Source: [ripienaar/free-for-dev](https://github.com/ripienaar/free-for-dev) (125k⭐, 7000+ commits).

## Scope

Services must offer a **permanent free tier** (not just a time-limited free trial). Self-hosted software is excluded — only as-a-Service offerings.

## Categories Covered

The full list at https://github.com/ripienaar/free-for-dev covers:

| Category | Examples |
|----------|----------|
| **Major Cloud Providers** | AWS (EC2 750hr, S3 5GB, Lambda 1M), GCP (e2-micro, BigQuery 1TB), Azure (B1S VM, Cosmos DB), Oracle Cloud (2 AMD/Arm VMs, 10TB egress), IBM Cloud, Cloudflare (Workers, R2, D1, Pages) |
| **Source Code Repos** | GitHub, GitLab, Bitbucket, Codeberg, GitGud |
| **CI/CD** | CircleCI (6K min/mo), Buildkite, Bitrise, Codemagic, Nx Cloud, Spacelift |
| **PaaS** | Heroku, Railway, Render, Fly.io, Northflank, Porter |
| **IaaS** | Various always-free VM tiers |
| **Databases** | MongoDB Atlas (512MB), Supabase (500MB), PlanetScale (5GB), Neon (512MB), Redis (30MB), TiDB |
| **Monitoring / Observability** | Datadog, Grafana Cloud, New Relic, Sentry (5K errors), UptimeRobot, Better Stack |
| **Auth / SSO** | Auth0 (7K users), Clerk, Supabase Auth, Firebase Auth, Okta |
| **Email** | SendGrid (100/day), Mailgun, Mailjet, Resend (100/day), Postmark |
| **Storage** | Backblaze B2 (10GB), Cloudflare R2 (10GB), Supabase Storage |
| **Serverless / Workers** | Cloudflare Workers (100K/day), Deno Deploy, Vercel Serverless |
| **APIs, Data & ML** | OpenAI, Anthropic, HuggingFace, Firecrawl, RapidAPI, CoinGecko |
| **CDN / DNS** | Cloudflare, BunnyCDN, jsDelivr |
| **Logging** | Logtail, Better Stack, Papertrail |
| **Push Notifications** | Firebase FCM, OneSignal, Pushover |
| **Forms** | Formspree, Formcarry, Getform |
| **Analytics** | Plausible, Umami, PostHog, Mixpanel |
| **Payments** | Stripe (test mode), Lemon Squeezy |
| **Media / Image** | Cloudinary, imgix, Uploadcare |
| **Chat / Comms** | Slack, Discord (bot APIs), Twilio |
| **Design** | Figma, Excalidraw |
| **Package / Artifact Registries** | npm, GitHub Packages, GitLab, Cloudsmith |
| **Secrets / Config** | Doppler, Infisical, HashiCorp Vault |
| **Status Pages** | Instatus, Better Uptime, Cachet |
| **Tunnel / Proxy** | ngrok, LocalTunnel, Cloudflare Tunnel |
| **VPN** | Cloudflare WARP, ProtonVPN |
| **Education / Learning** | freeCodeCamp, The Odin Project |

## How to Use This Skill

When the user asks about free-tier options for a service category:

1. **Identify the category** they need (cloud VM, database, email, auth, etc.)
2. **Reference the full list** at https://github.com/ripienaar/free-for-dev for the most up-to-date entries
3. **Use `web_extract`** on the raw README for the latest data: `https://raw.githubusercontent.com/ripienaar/free-for-dev/master/README.md`
4. **Compare limits** — free tiers change frequently; verify on the provider's pricing page before committing

## Quick Reference: Major Always-Free Tiers

### Compute
| Provider | Free Tier |
|----------|-----------|
| GCP e2-micro | 1 non-preemptible, 30GB HDD (select regions) |
| AWS t2/t3.micro | 750 hrs/month (12 months) |
| Azure B1S | 1 Linux + 1 Windows (12 months) |
| Oracle Cloud | 2× AMD (1/8 OCPU, 1GB) OR 2× Arm Ampere A1 (12GB RAM) — always free |
| Cloudflare Workers | 100K requests/day |

### Databases
| Provider | Free Tier |
|----------|-----------|
| Supabase | 500MB PostgreSQL, 500MB storage, 2GB file storage |
| PlanetScale | 5GB, 1B row reads/mo, 10K row writes/mo |
| Neon | 512MB, 10K compute hours/mo |
| MongoDB Atlas | 512MB (M0 cluster) |
| Upstash Redis | 30MB, 10K commands/day |
| TiDB | 5GB, 5K QPS (serverless) |

### Storage
| Provider | Free Tier |
|----------|-----------|
| Cloudflare R2 | 10GB, 1M Class A / 10M Class B ops |
| Backblaze B2 | 10GB |
| Supabase Storage | 1GB (free tier) |

### Email
| Provider | Free Tier |
|----------|-----------|
| SendGrid | 100 emails/day |
| Resend | 100 emails/day |
| Mailjet | 6K emails/month (200/day) |
| Postmark | 100 emails/month |

### Auth
| Provider | Free Tier |
|----------|-----------|
| Auth0 | 7K active users |
| Clerk | 10K MAU |
| Firebase Auth | Unlimited (phone auth has limits) |
| Supabase Auth | 50K MAU |

## Pitfalls

- **AWS free tier expires** after 12 months — not truly "always free"
- **Oracle Cloud** reclaims idle instances after 7 days of low utilization
- **Heroku** removed its free tier in 2022
- **PlanetScale** removed its free tier in 2023 (then reintroduced a limited one)
- **Always verify** current limits on the provider's pricing page — this list is community-maintained and may lag behind changes
