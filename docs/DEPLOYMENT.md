# Deployment Runbook

How to ship AgriSmart AI on free-tier services (target **₹0/month**): FastAPI on
Render, Flutter for Android, Supabase for Auth/Postgres/Storage, and
server-side integrations for weather and the AI assistant.

> This document contains **no secret values**. Set every secret in the Render
> dashboard (or a local gitignored `.env`) - never in git.

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
   - `backend/migrations/0001_init.sql` (profiles + RLS + signup trigger)
   - `backend/migrations/0002_community.sql` (posts/comments/likes + RLS + the
     public `community` storage bucket)
3. Enable the Email provider; optionally enable Confirm email.
4. (Optional) Configure Google Sign-In and its redirect URLs.

Both migrations are idempotent, so re-running them is safe.

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
- Community posts/images round-trip using a real signed-in account.
- Unconfigured features (chat without a provider, diagnose without a model)
  return **503**, never invented data.

## 9. Rollback

- Render keeps previous deploys: **Events -> Rollback** to a prior successful
  deploy.
- Database migrations are additive/idempotent; they are not auto-reverted.
- To pause cost/noise: set the Render service to **Suspend** or scale to zero.

## 10. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `database: unavailable` | `DATABASE_URL` missing/wrong; use the pooled URI and `postgresql+psycopg://`. |
| First request slow/failing | Render free instance slept; retry after warm-up. Supabase free project may have paused. |
| `401` on profile | `SUPABASE_JWT_SECRET` missing or asymmetric keys in use (see SETUP_SUPABASE.md). |
| Chat `503` | `AI_PROVIDER=none` or missing `AI_API_KEY`. |
| Diagnose `503` | `MODEL_PATH` empty or model not present in the container (step 5). |
| Rate limits hit in tests | `RATE_LIMIT_ENABLED=false` for local/CI only. |
