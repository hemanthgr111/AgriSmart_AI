# Free-Tier Limits & Cost Controls

AgriSmart AI is designed to run at **₹0/month** within the free tiers below.
This page records the limits we rely on, the code-level guardrails that keep us
inside them, and the upgrade path if usage grows.

> Limits are approximate and change over time. Always confirm on the provider's
> current pricing page before relying on a number.

## Service free tiers (approximate)

| Service | Purpose | Free-tier limits (approx.) | Gotchas |
|---|---|---|---|
| **Render** | FastAPI hosting | 750 instance-hours/month, 512 MB RAM, free HTTPS | Instance **sleeps after ~15 min** idle; cold start on next request; **ephemeral disk** (no persistent files) |
| **Supabase** | Postgres, Auth, Storage | ~500 MB database, ~1 GB file storage, limited egress, ~50k MAU | Project **pauses after ~1 week** of inactivity; API/storage egress is metered |
| **WeatherAPI.com** | Weather data | ~1M calls/month | 3-day forecast on free tier |
| **Google AI Studio (Gemini)** | AI assistant | Free tier with per-minute/day request caps | Rate limits vary; spikes return `429` |
| **Google Cloud** | OAuth (Google Sign-In) | Free | Requires OAuth consent setup |
| **Ollama** | Self-hosted AI (alternative) | "Free" only if you already run a host | Not free on managed cloud |

Paid-only options (OpenAI API) are supported but optional and off by default.

## Code-level cost guardrails

These are enforced by the backend (see `backend/app/core/config.py`,
`backend/app/core/rate_limit.py`, `backend/app/core/middleware.py`):

| Control | Setting | Default | Effect |
|---|---|---|---|
| Per-IP rate limit - chat | `RATE_LIMIT_CHAT` | `20/minute` | Caps AI provider calls |
| Per-IP rate limit - diagnose | `RATE_LIMIT_DIAGNOSE` | `30/minute` | Caps CPU/model usage |
| Per-IP rate limit - weather | `RATE_LIMIT_WEATHER` | `60/minute` | Protects the WeatherAPI quota |
| AI reply length cap | `AI_MAX_OUTPUT_TOKENS` | `800` | Bounds tokens billed per reply |
| Weather cache | `WEATHER_CACHE_TTL_SECONDS` | `600` | Reuses upstream results for 10 min |
| Request body cap | `MAX_REQUEST_BYTES` | ~12 MB | Rejects oversized bodies early |
| Image upload cap | `MAX_PHOTO_BYTES` | 5 MB | Limits decode/model cost |
| GZip | `GZIP_MIN_SIZE` | 1024 bytes | Reduces egress |
| API docs | `ENABLE_API_DOCS` | `false` in prod | Hides `/docs`, `/openapi.json` |
| Feature kill-switch | `AI_PROVIDER=none`, empty `MODEL_PATH` | off | Unconfigured features return `503` instead of spending money |

Rate-limit storage is **in-memory** (`RATE_LIMIT_STORAGE_URI=memory://`) and is
correct for a single instance. If you scale to multiple instances, point it at a
shared Redis and increase limits accordingly.

## Estimated usage envelope (single small instance)

- **Weather:** one cached lookup per unique location per 10 min. Even a busy
  village app stays far under 1M calls/month.
- **Chat:** 20 messages/min/IP; provider caps are the real ceiling. Keep
  `AI_MAX_OUTPUT_TOKENS` low and prefer a free-tier model.
- **Diagnose:** 30 requests/min/IP, each ~one CPU forward pass on a 224×224
  image. No GPU needed; keeps Render's free CPU viable.
- **Community media:** stored in Supabase Storage; watch the ~1 GB cap and
  prune abandoned uploads if needed.

## When to upgrade

| Symptom | Move to |
|---|---|
| Cold starts hurt UX | Render paid instance (no sleep) |
| Database/storage/egress near caps | Supabase Pro or archive old community media |
| Weather quota exceeded | Paid WeatherAPI plan |
| Gemini free caps too low | Paid Gemini/OpenAI tier or self-hosted Ollama |

The backend needs **no code change** to switch providers or scale - only
environment variables and (for multi-instance rate limiting) a Redis URI.

## Operational tips

- Monitor Render logs and the `/api/health` `database` field for early warnings.
- Suspend the Render service (or scale to zero) when not in use.
- Keep `ENABLE_API_DOCS=false` and `RATE_LIMIT_ENABLED=true` in production.
- Never enable a paid integration without an explicit budget decision.
