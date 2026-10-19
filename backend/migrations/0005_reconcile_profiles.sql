-- =============================================================================
-- AgriSmart AI - Forward-only reconcile: public.profiles -> target contract
-- Version 0005 (supersedes the removed malformed 0003 draft; never recorded).
-- Additive and idempotent.
--
-- Existing (live) database: every step below is already satisfied, so this
-- runs as a verified no-op. No migration history is assumed - each statement
-- is independently existence-guarded.
-- Fresh database: run AFTER 0001_init.sql to complete the profile schema
-- (0001 lacks username / preferred_language / the unique username index).
--
-- Behavior guarantees:
--   * Lazy-profile: registers NO trigger on auth.users. Profiles are created
--     by the backend on first PUT /api/profile.
--   * Access preservation: makes NO change to RLS policies or roles.
--   * No drops of data or objects; safe to re-run.
--
-- Known assumptions / limitations:
--   * Assumes public.profiles exists (created by 0001). This file is not a
--     substitute for 0001.
--   * On a FRESH database, 0001 still creates its historical signup trigger
--     (on_auth_user_created) because 0001 is immutable and this file
--     deliberately does not touch auth.users. The live database has no such
--     trigger (profiles are created lazily). Reconciling that difference is a
--     separate, explicitly reviewed change.
--   * The unique username index requires no duplicate usernames, and the
--     NOT NULL steps require no NULL timestamps. Run the documented pre-flight
--     checks before applying.
-- =============================================================================

-- 1) Columns possibly missing where the removed 0003 draft never ran (no-op if present)
alter table if exists public.profiles add column if not exists email text;
alter table if exists public.profiles add column if not exists bio text;
alter table if exists public.profiles add column if not exists updated_at timestamptz not null default now();

-- 2) ORM-contract columns absent from 0001
alter table if exists public.profiles add column if not exists username text;
alter table if exists public.profiles add column if not exists preferred_language text default 'en';

-- 3) Preferred-language default alignment (set-only, idempotent)
alter table if exists public.profiles alter column preferred_language set default 'en';

-- 4) Timestamp NOT NULL alignment (no-op when already NOT NULL)
alter table if exists public.profiles alter column created_at set not null;
alter table if exists public.profiles alter column updated_at set not null;

-- 5) Unique index on username (matches live schema + ORM unique=True)
create unique index if not exists profiles_username_key on public.profiles (username);

-- 6) updated_at trigger function (byte-identical to live / 0001)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- 7) Trigger created ONLY when missing (never drop/recreate on live)
do $$
begin
    if not exists (
        select 1 from pg_trigger t
        where t.tgrelid = 'public.profiles'::regclass
          and t.tgname = 'profiles_set_updated_at'
          and not t.tgisinternal
    ) then
        execute 'create trigger profiles_set_updated_at
                 before update on public.profiles
                 for each row execute function public.set_updated_at()';
    end if;
end $$;

-- 8) Ledger self-record ONLY if the ledger exists (no fabricated history)
insert into public.schema_migrations (version, name)
select '0005', '0005_reconcile_profiles.sql'
where exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'schema_migrations'
)
on conflict (version) do nothing;
