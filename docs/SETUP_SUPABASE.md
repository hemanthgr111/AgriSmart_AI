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

> If your project uses the newer asymmetric JWT signing keys, the backend's
> `app/core/security.py` must be extended to verify via the project JWKS. The
> current implementation verifies HS256 tokens with the JWT secret.

**Project Settings -> Database -> Connection string**

Use the **Connection pooling** (Supavisor, port `6543`) URI and prefix the
dialect for SQLAlchemy:

```
postgresql+psycopg://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres
```

Put this in `DATABASE_URL` in `backend/.env`.

## 3. Apply the database migrations

Run the migrations in order (each is idempotent and safe to re-run):

1. **SQL Editor -> New query**.
2. Paste the contents of
   [`backend/migrations/0001_init.sql`](../backend/migrations/0001_init.sql) and
   run it. This creates the `profiles` table, enables Row Level Security, adds
   ownership policies, and a trigger that creates a profile on signup.
3. New query again. Paste and run
   [`backend/migrations/0002_community.sql`](../backend/migrations/0002_community.sql).
   This creates the `posts`, `comments`, and `post_likes` tables with RLS
   policies, and creates the public `community` storage bucket with
   owner-scoped upload/delete policies.

> The community bucket is created by the migration; no manual Storage setup is
> required. Images are stored at `community/<user_id>/<timestamp>.jpg`.

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
SUPABASE_JWT_SECRET=<jwt-secret>           # backend only
```

## Free-tier notes

- Free projects are **paused after ~1 week of inactivity**; open the dashboard
  to resume, or expect the first request after a pause to fail until resumed.
- Free storage/database/egress are limited. See the README for details and
  monitoring guidance.
- Phone/SMS OTP is intentionally **not** enabled (no paid SMS provider).
