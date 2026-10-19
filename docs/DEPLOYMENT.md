# Deployment Runbook

How to ship AgriSmart AI on free-tier services (target **₹0/month**): FastAPI on
Render, Flutter for Android, Supabase for Auth/Postgres/Storage, and
server-side integrations for weather and the AI assistant.

> This document contains **no secret values**. Set every secret in the Render
> dashboard (or a local gitignored `.env`) - never in git.

> **Deployment not confirmed:** this runbook describes how to ship. No deployment
> has been performed or verified from this working tree, the migrations in
> Step 2 have **not** been applied, and the live Supabase integration remains
> **unverified**.

## 0. Architecture recap

```
Flutter app  --HTTPS-->  FastAPI (Render)  --HTTPS-->  Supabase Postgres
   |                         |                    \-->  WeatherAPI.com
   |                         \-->  AI provider (Gemini/OpenAI/Ollama)
   |                         \-->  PyTorch disease model (TorchScript)
   \-- Supabase SDK -->  Supabase Auth + Storage (RLS-enforced)
```

Only the Supabase **publishable/anon** key ships in the app. All other keys
(service-role, JWT secret, weather, AI) stay on the backend.

## 1. Prerequisites

- A GitHub account (a repository for this project).
- A [Render](https://render.com) account (free plan).
- A [Supabase](https://supabase.com) project.
- A [WeatherAPI.com](https://www.weatherapi.com) account + API key.
- Flutter SDK and Android tooling for building the app.
- Optional: an AI provider key (Google AI Studio / OpenAI) or a self-hosted Ollama.

## 2. Supabase (database, auth, storage)

Follow **[SETUP_SUPABASE.md](SETUP_SUPABASE.md)** once, then return here:

1. Create the project and collect `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, and the pooled
   `DATABASE_URL`.
2. Apply migrations **in order** in the SQL editor:
   - `backend/migrations/0004_schema_migrations.sql` (migration ledger - run first)
   - `backend/migrations/0001_init.sql` (base profiles + RLS + `updated_at`
     trigger **and** the historical `on_auth_user_created` signup trigger;
     `0001` is immutable, so a fresh database creates profiles eagerly; the live database has none and creates profiles lazily.)
   - `backend/migrations/0005_reconcile_profiles.sql` (completes the profiles
     contract: `username`, `preferred_language` default `'en'`, unique index,
     NOT NULL timestamps - a no-op on the live schema per a prior audit, not
     freshly verified)
   > An early, malformed `0003` draft was removed; `0005` supersedes it.
   > `0002` (community) is a later phase and must NOT be run against the live
   > database yet.
   >
   > None of these migrations have been applied to any database in this working
   > tree; the live Supabase schema has **not** been freshly verified, and
   > deployment has **not** been confirmed.
3. Enable the Email provider; optionally enable Confirm email.
4. (Optional) Configure Google Sign-In and its redirect URLs.

Each migration is idempotent, so re-running it is safe. Community storage
(`0002`) is deferred to a separate reconciliation phase.

## 3. Weather API

1. Sign up at WeatherAPI.com and copy the API key.
2. It becomes `WEATHER_API_KEY` on the backend. The key never reaches clients.

## 4. AI assistant provider (optional)

Set `AI_PROVIDER` to one of `none`, `gemini`, `openai`, `ollama`:

| Provider | Required settings |
|---|---|
| `none` | (default) Chat returns **503** - no fabricated answers. |
| `gemini` | `AI_API_KEY`; optional `AI_MODEL` (default `gemini-1.5-flash`). |
| `openai` | `AI_API_KEY`; optional `AI_MODEL` (default `gpt-4o-mini`). |
| `ollama` | `AI_BASE_URL` (default `http://localhost:11434`); no key. |

Keep `AI_MAX_OUTPUT_TOKENS` small (default `800`) to bound cost.

## 5. Crop-disease model (hosting caveat - important)

The backend serves `POST /api/diagnose` only when `MODEL_PATH` points at a
readable TorchScript file. The model is **not committed** (gitignored) and
Render's free tier has an **ephemeral filesystem**, so the file will not exist
in the container unless you provide it at build time.

Options (choose one):

- **Ship disabled (simplest):** leave `MODEL_PATH` empty. The endpoint returns
  **503** and the app shows a "not configured" message. No fabricated data.
- **Download during build:** extend `backend/render.yaml`'s `buildCommand` to
  fetch the model from private Supabase Storage (e.g. `curl` a signed URL into
  `models/`). The URL/key must be available at build time (Render env var).
- **Ship a small model in the image:** only if the artifact is small and you
  accept it in the repo - not recommended.

Train/export locally first:

```powershell
cd backend
pip install -r requirements.txt -r requirements-ml.txt
python ml/train.py --data-dir data --output models/crop_disease.pt --epochs 4
```

Then host `models/crop_disease.pt` somewhere the build can reach and set
`MODEL_PATH` accordingly. Do not attach a large dataset or run training in CI.

## 6. Deploy the backend (Render)

1. Push this repository to GitHub.
2. In Render: **New -> Blueprint**, connect the repo. Render reads
   `backend/render.yaml` and creates the `agrismart-api` web service (free plan,
   health check `/api/health`).
3. In the service's **Environment** tab, fill the variables marked `sync: false`
   in `render.yaml`:
   - `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
     `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`
   - `WEATHER_API_KEY`
   - `AI_API_KEY` (if using a hosted provider)
   - `MODEL_PATH` (only if you completed step 5)
   - `CORS_ORIGINS` (explicit origins, comma-separated; never `*` with credentials)
   - `ALLOWED_HOSTS` (e.g. `agrismart-api.onrender.com`, comma-separated)
   - The blueprint already sets `ENVIRONMENT=production`, `ENABLE_API_DOCS=false`,
     `RATE_LIMIT_ENABLED=true`, `AI_MAX_OUTPUT_TOKENS=800`, and
     `FORWARDED_ALLOW_IPS=*`.
4. Deploy and wait for the health check to pass.

The start command uses `--proxy-headers` so rate limiting sees the real client
IP behind Render's TLS proxy.

## 7. Build the Flutter app

```powershell
cd frontend
flutter build apk --release `
  --dart-define=API_BASE_URL=https://agrismart-api.onrender.com `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Omit the Supabase defines for a **guest-mode** build. Only the publishable key is
ever embedded - never the service-role key.

## 8. Post-deploy verification

- `GET https://<service>/api/health` returns `200` with `database: connected`.
- `/docs` and `/openapi.json` return **404** (docs disabled in production).
- Hammering `POST /api/chat` past the limit returns **429**.
- Community posts/images round-trip using a real signed-in account -
  **unverified/blocked**: the client does not match the previously recorded live
  schema, so this check has not passed.
- Unconfigured features (chat without a provider, diagnose without a model)
  return **503**, never invented data.

## 9. Rollback

- Render keeps previous deploys: **Events -> Rollback** to a prior successful
  deploy.
- Database migrations are additive/idempotent; they are not auto-reverted. To
  validate safely, run a migration inside `BEGIN; ... ROLLBACK;` first; see
  SETUP_SUPABASE.md for pre-flight checks and the migration ledger (0004).
- To pause cost/noise: set the Render service to **Suspend** or scale to zero.

## 10. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `database: unavailable` | `DATABASE_URL` missing/wrong; use the pooled URI and `postgresql+psycopg://`. |
| First request slow/failing | Render free instance slept; retry after warm-up. Supabase free project may have paused. |
| `401` on profile | Token invalid, expired, or wrong issuer/audience. For asymmetric projects, ensure the JWKS endpoint is reachable (see SETUP_SUPABASE.md). |
| Chat `503` | `AI_PROVIDER=none` or missing `AI_API_KEY`. |
| Diagnose `503` | `MODEL_PATH` empty or model not present in the container (step 5). |
| Rate limits hit in tests | `RATE_LIMIT_ENABLED=false` for local/CI only. |

## Appendix A. Production environment variables

Reference for shipping the backend. **Secret** values are set in the Render
dashboard (or a local gitignored `.env`) and are **never** committed;
[`backend/.env.example`](../backend/.env.example) lists placeholders only. The
blueprint [`backend/render.yaml`](../backend/render.yaml) already sets the
non-secret values and marks the rest `sync: false`.

### Backend (Render service)

| Variable | Required | Purpose | Safe value / notes |
|---|---|---|---|
| `ENVIRONMENT` | yes | Enables production behaviour. | `production` (set by `render.yaml`). |
| `DEBUG` | no | Verbose error output. | `false` in production. |
| `ENABLE_API_DOCS` | yes (prod) | Hides `/docs`, `/redoc`, `/openapi.json`. | `false` in production. |
| `DATABASE_URL` | yes | Postgres connection (SQLAlchemy + psycopg3). | **Secret.** Pooled Supavisor URI on `:6543`, prefixed `postgresql+psycopg://`. |
| `SUPABASE_URL` | yes | Project URL; also derives the JWT issuer. | `https://<ref>.supabase.co` (not secret). |
| `SUPABASE_ANON_KEY` | yes | Client-safe key (RLS-enforced). | Publishable/anon key. |
| `SUPABASE_SERVICE_ROLE_KEY` | if server-side privileged ops | Backend-only admin key. | **Secret.** Never ship to Flutter. |
| `SUPABASE_JWT_SECRET` | legacy HS256 only | Verifies legacy Supabase HS256 access tokens. | **Secret.** Project Settings -> API -> JWT Settings. Not needed for asymmetric projects. |
| `SUPABASE_JWT_ISSUER` | no | Pins the accepted token issuer. | Leave empty to derive `<SUPABASE_URL>/auth/v1`; set only to override. |
| `SUPABASE_JWKS_URL` | no | JWKS endpoint for asymmetric (ES256/RS256) tokens. | Leave empty to derive `<SUPABASE_URL>/auth/v1/.well-known/jwks.json`. |
| `REQUIRE_AUTH_FOR_AI` | decision | When `true`, `/api/chat`, `/api/diagnose`, `/api/weather` require a valid token. | Default `false` (guest mode). See "Production authentication setting". |
| `CORS_ORIGINS` | yes | Browser origin allow-list (comma-separated). | Explicit origins; never `*` together with credentials. The mobile app sends no browser origin. |
| `ALLOWED_HOSTS` | yes | `TrustedHostMiddleware` allow-list (comma-separated). | e.g. `agrismart-api.onrender.com`. |
| `FORWARDED_ALLOW_IPS` | no | uvicorn proxy-header trust. | See "Client IP and rate limiting". |
| `TRUSTED_PROXY_IPS` | no | Retained for compatibility; **no longer read** by application code. | The app keys on Uvicorn's resolved `request.client`, not on `X-Forwarded-For`. See "Client IP and rate limiting". |
| `RATE_LIMIT_ENABLED` | yes | Enables slowapi limits. | `true` in production. |
| `RATE_LIMIT_CHAT` / `RATE_LIMIT_DIAGNOSE` / `RATE_LIMIT_WEATHER` | no | Per-endpoint limits. | e.g. `20/minute`, `30/minute`, `60/minute`. |
| `RATE_LIMIT_STORAGE_URI` | scaling | Limiter storage backend. | `memory://` for a single instance; a Redis URI when scaling out. |
| `AI_PROVIDER` | no | Selects the assistant provider. | `none` / `gemini` / `openai` / `ollama`. |
| `AI_API_KEY` | per provider | Provider credential. | **Secret.** Required for `gemini` and `openai`. |
| `AI_MODEL` | no | Model override. | e.g. `gemini-1.5-flash`, `gpt-4o-mini`. |
| `AI_BASE_URL` | `ollama` only | Self-hosted endpoint. | e.g. `http://localhost:11434`. |
| `AI_MAX_OUTPUT_TOKENS` | no | Caps reply size and provider cost. | Keep small (default `800`). |
| `WEATHER_API_KEY` | yes | WeatherAPI.com key. | **Secret.** Server-side only. |
| `MODEL_PATH` | no | TorchScript disease-model path. | Empty -> `/api/diagnose` returns **503**. |
| `MAX_REQUEST_BYTES` / `MAX_PHOTO_BYTES` / `MAX_VIDEO_BYTES` | no | Request and upload size caps. | Defaults are conservative; see `.env.example`. |

### Flutter (build-time `--dart-define`)

| Value | Purpose |
|---|---|
| `API_BASE_URL` | Backend base URL, e.g. `https://agrismart-api.onrender.com`. |
| `SUPABASE_URL` | Project URL. Omit (with the key) for a guest-mode build. |
| `SUPABASE_ANON_KEY` | Publishable/anon key. Only public keys ship in the app. |

### Expected JWT issuer

Supabase access tokens are issued with `iss` = `https://<project-ref>.supabase.co/auth/v1`
and `aud` = `authenticated`. The backend pins the issuer automatically from
`SUPABASE_URL`; set `SUPABASE_JWT_ISSUER` only to override it. The backend
verifies both signing modes: legacy `HS256` tokens using `SUPABASE_JWT_SECRET`,
and asymmetric `ES256`/`RS256` tokens using the project JWKS at
`<SUPABASE_URL>/auth/v1/.well-known/jwks.json` (override with `SUPABASE_JWKS_URL`).
The algorithm is read from each token's header, so no mode switch is required -
see [SETUP_SUPABASE.md](SETUP_SUPABASE.md).

### Production authentication setting

`REQUIRE_AUTH_FOR_AI` defaults to `false`, so the AI/ML/weather endpoints stay
open (guest mode) and rate limiting is the primary guard. Set it to `true` to
require a valid Supabase token on those endpoints.

The Flutter client already sends the signed-in user's token as
`Authorization: Bearer <token>` for `POST /api/chat`, `POST /api/diagnose`, and
`GET /api/weather`. The token is read via `auth.getSession()`, which refreshes
an expired token on demand; if there is no session (or refresh fails) the header
is simply omitted and the request is treated as anonymous. In guest mode the
app omits the header as before.

> **Do not enable** `REQUIRE_AUTH_FOR_AI=true` (production authentication
> enforcement) until the client flow and this deployment configuration have been
> reviewed and approved. It is not required for a guest-mode release.

### Client IP and rate limiting

Render terminates TLS at its own proxy. Rate-limit keys prefer the authenticated
`sub`; anonymous callers fall back to the client IP as resolved by Uvicorn's
`--proxy-headers` handling (i.e. `request.client`). The application no longer
parses `X-Forwarded-For` itself — doing so added a second, independently
spoofable trust path. `TRUSTED_PROXY_IPS` is retained only for compatibility and
is not read by application code.

Residual risk: `--forwarded-allow-ips="*"` (and the `FORWARDED_ALLOW_IPS=*`
value) makes Uvicorn trust `X-Forwarded-For` from **any** peer. Under wildcard
trust Uvicorn adopts the **leftmost** header entry as the client IP, so an
anonymous caller can influence the IP used for rate-limit keys unless the edge
proxy overwrites that first entry with the true client address. Render's
documented convention is to place the real client IP first, but this is not a
versioned contract and cannot be verified from the repository; confirm it
against the deployed service before relying on anonymous IP rate limiting. Do
not assume a fixed set of proxy IPs: Render publishes *outbound* ranges and
*inbound* allowlist rules, not the inbound proxy IPs that `FORWARDED_ALLOW_IPS`
would need.

When a specific trusted host list is configured instead of `*`, Uvicorn selects
the rightmost `X-Forwarded-For` entry that is not itself a trusted host (so the
hop-selection rule differs from the wildcard case). Authenticated callers are
keyed by their token subject and are unaffected by any of this.

Mitigations: consider `REQUIRE_AUTH_FOR_AI=true` (see "Production authentication
setting") to remove anonymous IP reliance on externally backed endpoints, and
keep `RATE_LIMIT_STORAGE_URI` on a shared backend (e.g. Redis) when scaling out.
