# AgriSmart AI

An AI-powered agriculture app for farmers: crop disease detection, treatment
guidance, real-time weather, a multilingual AI farmer assistant, and a farmer
social community. Designed to run on **free-tier cloud services (target ₹0/month)**.

> Status: **Feature code implemented; end-to-end verification and deployment are
> unverified.** All planned phases are implemented in code, but the database
> migrations, live Supabase integration, and deployment have **not** been
> completed or confirmed. See "Project verification status" below for known
> blockers, [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) to ship, and
> [docs/FREE_TIER.md](docs/FREE_TIER.md) for limits and cost controls.

## Architecture

```
Flutter (Material 3, Android)
  |  Supabase Auth SDK (email + Google)      ->  Supabase Auth
  |  Supabase Storage SDK (signed uploads)   ->  Supabase Storage
  |  RLS-protected reads of public data      ->  Supabase Postgres
  |
  +--HTTPS--> FastAPI (Render Free)
                |-- /api/health
                |-- Supabase Postgres (SQLAlchemy + psycopg3)
                |-- WeatherAPI.com (server-side key)
                +-- AI provider (server-side key, pluggable) + PyTorch disease model
```

Secrets live only on the backend. The Flutter app ships only the Supabase
publishable/anon key (safe under Row Level Security).

## Repository layout

```
AgriSmart_AI/
  backend/            FastAPI service
    app/
      core/           config, logging
      db/             engine + session
      api/routes/     endpoint modules
      schemas/        Pydantic request/response models
      services/       integrations (weather, AI, storage, ML)
      ml/             disease model: labels + inference (TorchScript)
    ml/               offline training/export script (not shipped to runtime)
    tests/
    requirements.txt
    requirements-ml.txt
    requirements-dev.txt   ruff (lint) for local/CI use
    pyproject.toml         ruff configuration
    .env.example
  frontend/           Flutter application
  docs/               setup, deployment, and free-tier guides
  .github/workflows/  CI (ruff + pytest, flutter analyze + test)
  .gitignore
  README.md
```

## Prerequisites

- Python 3.11 - 3.13 recommended for the backend (see notes below).
- Flutter 3.16+ / Dart 3.x.
- Git.

> **Note:** TensorFlow does not support Python 3.14, and Render's free tier
> runs an older Python. The disease model uses **PyTorch**. For local backend
> work on this machine (Python 3.14), most dependencies install fine; if a
> driver wheel is missing, create a Python 3.12 virtual environment.

## Backend setup (local)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env   # then edit .env with your values
uvicorn app.main:app --reload
```

- Health check: <http://127.0.0.1:8000/api/health>
- Interactive API docs: <http://127.0.0.1:8000/docs>

The service starts even without credentials; the `/api/health` response reports
`database: unavailable` until `DATABASE_URL` is configured.

## Backend tests

```powershell
cd backend
pytest -q
```

## Linting

```powershell
cd backend
pip install -r requirements-dev.txt
ruff check app tests
```

`ruff` is configured in `backend/pyproject.toml` (rules `E`, `F`, `I`, `UP`;
`E501` ignored). The Flutter app uses `flutter_lints` via
`frontend/analysis_options.yaml`.

### Formatting (optional follow-up)

The Flutter sources are **not** currently `dart format`-clean: running
`dart format --output=none --set-exit-if-changed lib test` reports **41 files**
that would change. This is intentionally **out of scope** for Phase 9 to avoid a
large, unrelated diff, and CI does **not** run a formatting gate. If you want to
enforce formatting later, run `dart format lib test` in a dedicated commit and
then add `dart format --output=none --set-exit-if-changed lib test` to the
frontend CI job.

## Continuous integration

`.github/workflows/ci.yml` runs on every push/PR to `main`:

- **Backend:** installs `requirements-dev.txt`, runs `ruff check app tests` and
  `pytest -q` (no secrets required; external calls are mocked).
- **Frontend:** `flutter pub get`, `flutter gen-l10n`, `flutter analyze`,
  `flutter test`.

CI requires a GitHub remote; it does not deploy and needs no credentials.

## Flutter setup (local)

```powershell
cd frontend
flutter pub get
flutter run
```

To enable authentication, provide Supabase credentials at build time (the app
runs in **guest mode** without them):

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key> `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

See **[docs/SETUP_SUPABASE.md](docs/SETUP_SUPABASE.md)** for the full Supabase,
database-migration, and Google Sign-In setup.

### Supported languages

English, Hindi, Bengali, Marathi, Telugu, Tamil, Gujarati, Urdu (RTL), Kannada.
Localization uses ARB files in `frontend/lib/l10n/` and Flutter's `gen-l10n`.
Regenerate after editing strings with `flutter gen-l10n`.

## Environment variables

See [`backend/.env.example`](backend/.env.example) for the full list. Never
commit a real `.env` file.

## Crop disease model (PyTorch)

The backend serves `POST /api/diagnose` (multipart, field `file`). Inference
uses a **TorchScript** model produced by `backend/ml/train.py`, loaded from
`MODEL_PATH`. If `MODEL_PATH` is empty or the file is missing, the endpoint
returns **503** ("not configured") rather than guessing.

Train/export once (needs the 38-class PlantVillage dataset as an `ImageFolder`
with `train/` and `val/` splits):

```powershell
cd backend
pip install -r requirements.txt -r requirements-ml.txt
python ml/train.py --data-dir data --output models/crop_disease.pt --epochs 4
# then set MODEL_PATH=models/crop_disease.pt in backend/.env
```

The exported file expects a normalized `1x3x224x224` input and returns logits in
the order of `app/ml/labels.py:CLASSES`. Model files and datasets are gitignored.
TorchScript (`torch.jit`) is used instead of `torch.export` for broad runtime
support; note it emits deprecation warnings on Python 3.14 (the deploy target is
3.12).

## AI farmer assistant

The app sends conversations to `POST /api/chat`; the backend calls the
configured provider and returns text. Provider and key stay **server-side**;
the Flutter app never holds an AI key. With no provider configured, the
endpoint returns **503** and the app shows a localized "not set up" message.

Set one of these in `backend/.env` (`AI_PROVIDER`):

| Provider | Notes |
|---|---|
| `gemini` | Free tier. `AI_API_KEY` required. Default model `gemini-1.5-flash`. |
| `openai` | `AI_API_KEY` required. Default model `gpt-4o-mini`. |
| `ollama` | Self-hosted, no key. `AI_BASE_URL` defaults to `http://localhost:11434`. |

`AI_MODEL` and `AI_BASE_URL` are optional overrides. The assistant always
answers in the app's selected language (passed as `locale`). Chat history is
stored **on-device only** (SharedPreferences) and is not written server-side.

## Farmer community

Signed-in farmers can post text and a photo, like and comment. The Flutter app
talks to **Supabase directly** (Postgres + Storage) using the anonymous key;
authorization is enforced entirely by **Row Level Security** policies in
[`backend/migrations/0002_community.sql`](backend/migrations/0002_community.sql).
No community API runs on the FastAPI backend.

> **Unverified / blocked:** the community client does **not** match the
> previously recorded live schema, so this feature is currently non-functional.
> Recorded mismatches include the likes table name (`post_likes` in the client
> and `0002` vs `likes` live), the post/comment author column (`author_id` vs
> `user_id`), the post image column (`image_path` vs `media_url`/`media_type`),
> and the storage bucket (`community` vs `community-media`). The live schema has
> **not** been freshly verified and `0002` has **not** been applied. No
> client/schema reconciliation has been done yet.

- Feed, composer, and post detail are in `frontend/lib/features/community/`.
- Images are intended for a public storage bucket under `<user_id>/...` with
  owner-only writes. The client currently targets `community`; a prior audit
  recorded the live bucket as `community-media` (not freshly verified).
- The feature requires sign-in. Without Supabase credentials the app runs in
  guest mode and the community screen shows a localized "not configured" state.

> **Migrations not applied:** the migrations below have **not** been applied to
> any database and their end-to-end effect is **not verified**. Apply in order -
> `0004_schema_migrations.sql` (ledger), then `0001_init.sql`,
> `0005_reconcile_profiles.sql`, and `0002_community.sql` for the community
> feature (currently unresolved) - see
> [docs/SETUP_SUPABASE.md](docs/SETUP_SUPABASE.md).

## Security & cost controls

Applied on the backend (`backend/app/core/middleware.py`,
`backend/app/core/rate_limit.py`, `backend/app/main.py`):

- **Rate limiting** (per client IP, `slowapi`) on the endpoints that call paid
  or external services: `POST /api/chat`, `POST /api/diagnose`,
  `GET /api/weather`. Limits are configurable (`RATE_LIMIT_*`); storage is
  in-memory for a single instance (point `RATE_LIMIT_STORAGE_URI` at Redis to
  scale out).
- **Token-cap on AI replies** (`AI_MAX_OUTPUT_TOKENS`) bounds assistant cost.
- **Body-size limit** (`MAX_REQUEST_BYTES`) rejects oversized requests before
  they are read into memory; upload endpoints keep their own image limits.
- **GZip** compression to cut egress; **security headers** (`X-Content-Type-Options`,
  `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, HSTS in production).
- **CORS** only enables credentials for an explicit origin allow-list (never
  with `*`); **TrustedHost** can restrict the `Host` header.
- **API docs** (`/docs`, `/redoc`, `/openapi.json`) are disabled in production
  via `ENABLE_API_DOCS=false`.
- Behind a proxy (Render), run uvicorn with `--proxy-headers` so the real
  client IP is used for rate limiting.

`.env.example` contains **placeholders only**; real secrets live in the
gitignored `.env` and in the Render dashboard.

## Free-tier cloud services (to configure)

| Service | Purpose | Free-tier notes |
|---|---|---|
| Supabase | Postgres, Auth, Storage | ~500 MB DB, 1 GB storage, limited egress; pauses when idle |
| Render | FastAPI hosting | Free instance sleeps after ~15 min idle; cold starts |
| WeatherAPI.com | Weather data | ~1M calls/month free tier |
| Google Cloud | OAuth for Google Sign-In | Free |
| Cloudinary | Optional media (future) | Only if Supabase Storage is insufficient |

Limits are approximate and may change. See
**[docs/FREE_TIER.md](docs/FREE_TIER.md)** for the full limits and the
code-level cost controls that keep the app within them.

## Security warnings

- Never commit `.env`, service-role keys, JWT secrets, or OAuth secrets.
- Never embed a Supabase **service-role** key in Flutter code.
- All user media is private by default; only deliberately published public
  posts are readable.
- HTTPS alone does not imply security - database/storage authorization is
  verified with RLS policies and tests.

## Project verification status

The following are **unverified or not yet done** in this working tree; do not
treat them as complete:

- **Database migrations have not been applied** to any database, and the live
  Supabase schema has **not** been freshly verified (only a prior, recorded
  audit exists).
- **Deployment has not been confirmed:** there is no deploy evidence, and CI has
  not run because the working tree is uncommitted.
- **Crop disease model artifact is missing:** `backend/models/` is empty and
  model files are gitignored, so `POST /api/diagnose` returns **503** until a
  model is provided and `MODEL_PATH` is set. No model has been trained or
  shipped here.
- **Gemini API configuration is required** for live AI assistant responses;
  with no provider or `AI_API_KEY` configured, the assistant returns **503**.
- **Live Supabase credentials and integration remain unverified.**
- **Community client/schema mismatches remain unresolved** (see "Farmer
  community" above).

## Roadmap

> Checked items reflect code implementation only; end-to-end verification and
> deployment are not confirmed (see "Project verification status" above).

- [x] Phase 1 - Inspection & plan
- [x] Phase 2 - Application foundation
- [x] Phase 3 - Authentication & localization
- [x] Phase 4 - Weather
- [x] Phase 5 - Crop disease detection
- [x] Phase 6 - AI farmer assistant
- [x] Phase 7 - Social community
- [x] Phase 8 - Security & cost optimization
- [x] Phase 9 - Testing & deployment
