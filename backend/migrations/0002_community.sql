-- =============================================================================
-- AgriSmart AI - Phase 7: Community (posts, comments, likes, images)
-- Run this in the Supabase SQL editor (Dashboard > SQL Editor > New query).
-- It is idempotent and safe to re-run.
--
-- Depends on 0001_init.sql (public.profiles).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- posts: a farmer's text and/or image post.
-- ---------------------------------------------------------------------------
create table if not exists public.posts (
    id          uuid primary key default gen_random_uuid(),
    author_id   uuid not null references public.profiles (id) on delete cascade,
    content     text not null check (char_length(content) between 1 and 2000),
    image_path  text,
    created_at  timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_id_idx on public.posts (author_id);

alter table public.posts enable row level security;

-- The feed is publicly readable.
drop policy if exists "posts_select_all" on public.posts;
create policy "posts_select_all"
    on public.posts for select
    using (true);

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
    on public.posts for insert
    with check (auth.uid() = author_id);

drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own"
    on public.posts for update
    using (auth.uid() = author_id)
    with check (auth.uid() = author_id);

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own"
    on public.posts for delete
    using (auth.uid() = author_id);

-- ---------------------------------------------------------------------------
-- comments: replies on a post.
-- ---------------------------------------------------------------------------
create table if not exists public.comments (
    id          uuid primary key default gen_random_uuid(),
    post_id     uuid not null references public.posts (id) on delete cascade,
    author_id   uuid not null references public.profiles (id) on delete cascade,
    content     text not null check (char_length(content) between 1 and 1000),
    created_at  timestamptz not null default now()
);

create index if not exists comments_post_id_idx
    on public.comments (post_id, created_at);

alter table public.comments enable row level security;

drop policy if exists "comments_select_all" on public.comments;
create policy "comments_select_all"
    on public.comments for select
    using (true);

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own"
    on public.comments for insert
    with check (auth.uid() = author_id);

drop policy if exists "comments_delete_own" on public.comments;
create policy "comments_delete_own"
    on public.comments for delete
    using (auth.uid() = author_id);

-- ---------------------------------------------------------------------------
-- post_likes: one row per (post, user).
-- ---------------------------------------------------------------------------
create table if not exists public.post_likes (
    post_id     uuid not null references public.posts (id) on delete cascade,
    user_id     uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (post_id, user_id)
);

alter table public.post_likes enable row level security;

drop policy if exists "post_likes_select_all" on public.post_likes;
create policy "post_likes_select_all"
    on public.post_likes for select
    using (true);

drop policy if exists "post_likes_insert_own" on public.post_likes;
create policy "post_likes_insert_own"
    on public.post_likes for insert
    with check (auth.uid() = user_id);

drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own"
    on public.post_likes for delete
    using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Storage: public bucket for community images. Files are stored under a
-- "<user_id>/<timestamp>.<ext>" prefix so ownership can be enforced.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('community', 'community', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "community_images_read" on storage.objects;
create policy "community_images_read"
    on storage.objects for select
    using (bucket_id = 'community');

drop policy if exists "community_images_insert_own" on storage.objects;
create policy "community_images_insert_own"
    on storage.objects for insert to authenticated
    with check (
        bucket_id = 'community'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "community_images_delete_own" on storage.objects;
create policy "community_images_delete_own"
    on storage.objects for delete to authenticated
    using (
        bucket_id = 'community'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
