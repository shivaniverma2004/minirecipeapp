-- =============================================================================
-- miniRecipe — COMPLETE Supabase schema (A → Z)
-- =============================================================================
-- Use this for a NEW project: paste the whole file into
-- Dashboard → SQL → New query → Run once.
--
-- Includes: tables, indexes, RLS, signup trigger + profile row, likes RPC,
--           public storage buckets (recipe-images, avatars).
--
-- Notes:
-- • recipes.author_id is TEXT (app sends lowercased UUID string). RLS compares
--   with lower(trim(author_id)) = lower(auth.uid()::text) so Swift/Postgres
--   UUID casing never blocks inserts.
-- • Likes are updated via set_recipe_likes() (security definer), not direct
--   client UPDATE on recipes, so recipe row RLS stays author-only for UPDATE.
--
-- After running: Dashboard → Storage → confirm buckets `recipe-images` and
-- `avatars` exist and are public (this script inserts them). If images 404,
-- check bucket public flag and your project’s Storage URL in the app.
-- =============================================================================

-- ── Extensions (gen_random_uuid; usually already enabled on Supabase) ──────

create extension if not exists "pgcrypto";

-- ── Tables ───────────────────────────────────────────────────────────────────

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  image_url text,
  author_id text not null,
  likes int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references auth.users (id) on delete cascade,
  following_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self check (follower_id <> following_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  type text not null,
  title text not null,
  body text,
  recipe_id uuid references public.recipes (id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.recipe_likes (
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (recipe_id, user_id)
);

-- ── Indexes ──────────────────────────────────────────────────────────────────

create index if not exists recipes_author_id_idx
  on public.recipes (author_id);

create index if not exists recipes_created_at_idx
  on public.recipes (created_at desc);

create index if not exists notifications_user_id_created_at_idx
  on public.notifications (user_id, created_at desc);

create index if not exists recipe_likes_recipe_idx
  on public.recipe_likes (recipe_id, created_at desc);

create index if not exists recipe_likes_user_idx
  on public.recipe_likes (user_id, created_at desc);

create index if not exists follows_following_idx
  on public.follows (following_id);

create index if not exists follows_follower_idx
  on public.follows (follower_id);

-- ── RPC: likes (authenticated users; bypasses strict recipe UPDATE RLS) ────

create or replace function public.set_recipe_likes(p_recipe_id uuid, p_likes int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  update public.recipes
  set likes = greatest(0, p_likes)
  where id = p_recipe_id;
end;
$$;

revoke all on function public.set_recipe_likes(uuid, int) from public;
grant execute on function public.set_recipe_likes(uuid, int) to authenticated;

-- ── Row Level Security ───────────────────────────────────────────────────────

alter table public.recipes enable row level security;
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.notifications enable row level security;
alter table public.recipe_likes enable row level security;

-- recipes
drop policy if exists "recipes_select" on public.recipes;
drop policy if exists "recipes_insert" on public.recipes;
drop policy if exists "recipes_update_likes" on public.recipes;
drop policy if exists "recipes_author_update" on public.recipes;
drop policy if exists "recipes_author_delete" on public.recipes;

create policy "recipes_select"
  on public.recipes for select
  using (true);

create policy "recipes_insert"
  on public.recipes for insert
  with check (
    auth.uid() is not null
    and lower(trim(author_id)) = lower(auth.uid()::text)
  );

create policy "recipes_author_update"
  on public.recipes for update
  using (lower(trim(author_id)) = lower(auth.uid()::text))
  with check (lower(trim(author_id)) = lower(auth.uid()::text));

create policy "recipes_author_delete"
  on public.recipes for delete
  using (lower(trim(author_id)) = lower(auth.uid()::text));

-- profiles
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_all_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;

create policy "profiles_select"
  on public.profiles for select
  using (true);

-- SELECT/INSERT/UPDATE/DELETE own row (id = auth user)
create policy "profiles_all_own"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Extra insert policy: safe if you ever split policies; permissive OR with above
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

-- follows
drop policy if exists "follows_select" on public.follows;
drop policy if exists "follows_insert" on public.follows;
drop policy if exists "follows_delete" on public.follows;

create policy "follows_select"
  on public.follows for select
  using (true);

create policy "follows_insert"
  on public.follows for insert
  with check (auth.uid() = follower_id);

create policy "follows_delete"
  on public.follows for delete
  using (auth.uid() = follower_id);

-- notifications
drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_insert_actor" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;

create policy "notifications_select_own"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "notifications_insert_actor"
  on public.notifications for insert
  with check (auth.uid() = actor_id);

create policy "notifications_update_own"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- recipe_likes
drop policy if exists "recipe_likes_select" on public.recipe_likes;
drop policy if exists "recipe_likes_insert_own" on public.recipe_likes;
drop policy if exists "recipe_likes_delete_own" on public.recipe_likes;

create policy "recipe_likes_select"
  on public.recipe_likes for select
  using (true);

create policy "recipe_likes_insert_own"
  on public.recipe_likes for insert
  with check (auth.uid() = user_id);

create policy "recipe_likes_delete_own"
  on public.recipe_likes for delete
  using (auth.uid() = user_id);

-- ── Auth trigger: create / upsert profile on signup ───────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      split_part(coalesce(new.email, 'user'), '@', 1)
    )
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- ── Storage: recipe images (public bucket) ───────────────────────────────────

insert into storage.buckets (id, name, public)
values ('recipe-images', 'recipe-images', true)
on conflict (id) do update
  set public = excluded.public;

drop policy if exists "recipe_images_public_read" on storage.objects;
drop policy if exists "recipe_images_auth_upload" on storage.objects;
drop policy if exists "recipe_images_auth_update" on storage.objects;
drop policy if exists "recipe_images_auth_delete" on storage.objects;

create policy "recipe_images_public_read"
  on storage.objects for select
  using (bucket_id = 'recipe-images');

create policy "recipe_images_auth_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'recipe-images'
    and auth.role() = 'authenticated'
  );

create policy "recipe_images_auth_update"
  on storage.objects for update
  using (
    bucket_id = 'recipe-images'
    and auth.role() = 'authenticated'
  );

create policy "recipe_images_auth_delete"
  on storage.objects for delete
  using (
    bucket_id = 'recipe-images'
    and auth.role() = 'authenticated'
  );

-- ── Storage: avatars (public bucket; object name = `{uuid}.ext` at root) ─────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update
  set public = excluded.public;

drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_auth_upload_own" on storage.objects;
drop policy if exists "avatars_auth_update_own" on storage.objects;
drop policy if exists "avatars_auth_delete_own" on storage.objects;

create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars_auth_upload_own"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
    and lower(split_part(name, '.', 1)) = lower(auth.uid()::text)
  );

create policy "avatars_auth_update_own"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
    and lower(split_part(name, '.', 1)) = lower(auth.uid()::text)
  );

create policy "avatars_auth_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
    and lower(split_part(name, '.', 1)) = lower(auth.uid()::text)
  );

-- =============================================================================
-- End of schema
-- =============================================================================
