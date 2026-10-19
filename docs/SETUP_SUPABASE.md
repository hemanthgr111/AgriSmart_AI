# Supabase + Authentication Setup

This guide covers the manual dashboard steps that cannot be automated. Do these
once; then the app can authenticate users.

## 1. Create the Supabase project

1. Go to <https://supabase.com/dashboard> and sign in.
2. **New project** -> choose an organisation, name (e.g. `agrismart`), and a
   strong database password. Choose the region closest to your users
   (e.g. Mumbai / Singapore if offered).
3. Wait for provisioning (a few minutes).

## 2. Collect your keys

**Project Settings -> API**

| Value | Where it goes | Secret? |
|---|---|---|
| Project URL | `SUPABASE_URL` (backend) / `--dart-define` (Flutter) | No |
| Publishable / anon key | `SUPABASE_ANON_KEY` (backend) / `--dart-define` (Flutter) | No (safe under RLS) |
| Service role key | `SUPABASE_SERVICE_ROLE_KEY` (backend only) | **YES - never ship to Flutter** |

**Project Settings -> API -> JWT Settings**

| Value | Where it goes | Secret? |
|---|---|---|
| JWT secret | `SUPABASE_JWT_SECRET` (backend only) | **YES** |

> The backend verifies **both** signing modes. Legacy projects using the shared
> secret (`HS256`) are validated with `SUPABASE_JWT_SECRET`; projects on the
> newer asymmetric signing keys (`ES256`/`RS256`) are validated against the
> project JWKS at `<SUPABASE_URL>/auth/v1/.well-known/jwks.json` (override with
> `SUPABASE_JWKS_URL`). The algorithm is taken from each token's header, so no
> extra configuration is needed to switch modes.

The backend derives the expected token **issuer** from `SUPABASE_URL`
(`https://<project-ref>.supabase.co/auth/v1`, matching the `iss` claim in
Supabase tokens); set `SUPABASE_JWT_ISSUER` only to override that default. When
a user is signed in, the Flutter app sends their Supabase access token to the
backend AI/ML/weather endpoints as `Authorization: Bearer <token>` (refreshing
it on demand); in guest mode it sends no token.

**Project Settings -> Database -> Connection string**

Use the **Connection pooling** (Supavisor, port `6543`) URI and prefix the
dialect for SQLAlchemy:

```
postgresql+psycopg://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres
```

Put this in `DATABASE_URL` in `backend/.env`.

## 3. Apply the database migrations

Run the migrations in this order (each is idempotent and safe to re-run):

1. **SQL Editor -> New query**.
2. Paste the contents of
   [`backend/migrations/0004_schema_migrations.sql`](../backend/migrations/0004_schema_migrations.sql)
   and run it **first**. It creates the `public.schema_migrations` tracking
   table and records its own execution. A migration may be recorded in this
   ledger **only after** it executed successfully against the database in
   question; no historical migration is pre-seeded, because the application
   history of `0001`-`0003` is not verified.
3. New query again. Paste the contents of
   [`backend/migrations/0001_init.sql`](../backend/migrations/0001_init.sql) and
   run it. This creates the base `profiles` table, enables Row Level Security,
   adds ownership policies, the `updated_at` trigger, **and** the historical
   `on_auth_user_created` signup trigger. Because `0001` is immutable, that
   trigger still runs on a fresh database; the live database has none (profiles are created lazily by the backend). `0005` does not remove it.
4. New query again. Paste and run
   [`backend/migrations/0005_reconcile_profiles.sql`](../backend/migrations/0005_reconcile_profiles.sql).
   This aligns `profiles` with the application contract: `username`,
   `preferred_language` (default `'en'`), the unique index on `username`, and
   NOT NULL `created_at`/`updated_at`. A prior audit recorded this as a no-op
   on the live schema (**not freshly verified**).

> An early, malformed reconcile draft (numbered `0003`) has been removed;
> `0005` supersedes it. The community migration `0002` is a separate phase and
> is **not** part of this change set; do not run it against the live database yet.
> The community client is also known to mismatch the previously recorded live
> schema (see the README), so community reconciliation remains **unresolved**.

### Migration status and limitations

- `0001`-`0003` predate the ledger; whether they were applied is **not
  verified**. Never record them in `public.schema_migrations` without evidence
  that they executed on the database in question.
- None of the migrations in this guide have been applied to any database in this
  working tree, and the live Supabase schema has **not** been freshly verified
  (only a prior, recorded audit exists).
- Fresh-database validation has **not** been performed (no isolated scratch
  database is available). Before production use, validate the
  `0004 -> 0001 -> 0005` sequence on a scratch database.
- A fresh database runs `0001`'s historical `on_auth_user_created` signup
  trigger (eager profile creation), whereas the live database has no such
  trigger and creates profiles lazily. `0005` deliberately does not alter
  `auth.users`, so this divergence is documented, not fixed; reconciling it
  requires a separate, reviewed change.
- Migrations are additive and forward-only; there is no automatic revert. To
  recover from a failed run, fix the underlying data issue and re-run the same
  file (it is idempotent).
- Safe pre-flight checks before running `0005`:
  - `SELECT count(*) FROM public.profiles WHERE created_at IS NULL OR updated_at IS NULL;` -> expect `0`.
  - `SELECT username, count(*) FROM public.profiles GROUP BY username HAVING count(*) > 1;` -> expect no rows.
- To validate without committing changes, wrap the migration in
  `BEGIN; ... ROLLBACK;`.

## 4. Enable email/password auth

**Authentication -> Providers -> Email**

- Enable **Email** provider.
- Optionally enable **Confirm email** (recommended for production). When on,
  new users must verify their email before signing in; the app shows a
  verification screen.

**Authentication -> URL Configuration**

- Add your app's redirect URLs (e.g. `io.supabase.agrismart://login-callback`
  for the mobile deep link in this project).

## 5. Google Sign-In (via Supabase Auth)

1. **Google Cloud Console -> APIs & Services -> Credentials**
   - Create an **OAuth client ID** of type **Web application**.
   - Authorized redirect URI:
     `https://<your-project-ref>.supabase.co/auth/v1/callback`
2. Copy the **Client ID** and **Client secret**.
3. In Supabase **Authentication -> Providers -> Google**: enable it and paste
   the Client ID/secret.
4. For an Android build, create an additional OAuth client of type
   **Android**, using your app's package name (`com.agrismart.agrismart_app`)
   and the **SHA-1** of your signing key:
   ```powershell
   # debug keystore
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
5. Test register, login, logout, and session restoration on a real flow.

## 6. Run the app with credentials

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable-key> `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator -> host
```

Omit the Supabase defines to run in **guest mode** (no login) while developing.

## 7. Backend `.env`

```
DATABASE_URL=postgresql+psycopg://...
SUPABASE_URL=https://<ref>.supabase.co
SUPABASE_ANON_KEY=<publishable-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role>   # backend only
SUPABASE_JWT_SECRET=<jwt-secret>           # backend only (legacy HS256 projects)
SUPABASE_JWKS_URL=                         # optional; derived from SUPABASE_URL
```

## Free-tier notes

- Free projects are **paused after ~1 week of inactivity**; open the dashboard
  to resume, or expect the first request after a pause to fail until resumed.
- Free storage/database/egress are limited. See the README for details and
  monitoring guidance.
- Phone/SMS OTP is intentionally **not** enabled (no paid SMS provider).
