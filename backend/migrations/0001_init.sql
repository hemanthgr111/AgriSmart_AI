-- =============================================================================
-- AgriSmart AI - Initial schema (Phase 3: user profiles)
-- Run this in the Supabase SQL editor (Dashboard > SQL Editor > New query).
-- It is idempotent and safe to re-run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles: public-facing user data, keyed by the auth user id.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    email       text,
    full_name   text,
    avatar_url  text,
    bio         text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Profiles are publicly readable (needed to show post authors later).
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all"
    on public.profiles for select
    using (true);

-- A user may create only their own profile row.
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
    on public.profiles for insert
    with check (auth.uid() = id);

-- A user may update only their own profile row.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
    on public.profiles for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- Automatically create a profile when a user signs up.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email, full_name, avatar_url)
    values (
        new.id,
        new.email,
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'avatar_url'
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Keep updated_at current.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
    before update on public.profiles
    for each row execute function public.set_updated_at();
