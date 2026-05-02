-- Run on an existing miniRecipe Supabase project that already had `recipes` / `profiles`.
-- Safe to run multiple times (uses IF NOT EXISTS / DROP IF EXISTS where possible).

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

create index if not exists notifications_user_id_created_at_idx
  on public.notifications (user_id, created_at desc);

-- RPC for likes (keeps RLS tight on direct UPDATE)
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
  update public.recipes set likes = greatest(0, p_likes) where id = p_recipe_id;
end;
$$;

revoke all on function public.set_recipe_likes(uuid, int) from public;
grant execute on function public.set_recipe_likes(uuid, int) to authenticated;

-- Tighten recipe insert: author must match JWT
drop policy if exists "recipes_insert" on public.recipes;
create policy "recipes_insert"
  on public.recipes for insert
  with check (auth.uid() is not null and author_id = auth.uid()::text);

drop policy if exists "recipes_author_update" on public.recipes;
drop policy if exists "recipes_author_delete" on public.recipes;
create policy "recipes_author_update"
  on public.recipes for update
  using (author_id = auth.uid()::text)
  with check (author_id = auth.uid()::text);
create policy "recipes_author_delete"
  on public.recipes for delete
  using (author_id = auth.uid()::text);

drop policy if exists "recipes_update_likes" on public.recipes;

alter table public.follows enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "follows_select" on public.follows;
drop policy if exists "follows_insert" on public.follows;
drop policy if exists "follows_delete" on public.follows;
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

drop policy if exists "notifications_select_own" on public.notifications;
drop policy if exists "notifications_insert_actor" on public.notifications;
drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_select_own" on public.notifications for select using (auth.uid() = user_id);
create policy "notifications_insert_actor" on public.notifications for insert with check (auth.uid() = actor_id);
create policy "notifications_update_own" on public.notifications for update using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_auth_upload_own" on storage.objects;
drop policy if exists "avatars_auth_update_own" on storage.objects;
drop policy if exists "avatars_auth_delete_own" on storage.objects;

create policy "avatars_public_read" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars_auth_upload_own" on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.role() = 'authenticated' and name like auth.uid()::text || '.%');
create policy "avatars_auth_update_own" on storage.objects for update
  using (bucket_id = 'avatars' and auth.role() = 'authenticated' and name like auth.uid()::text || '.%');
create policy "avatars_auth_delete_own" on storage.objects for delete
  using (bucket_id = 'avatars' and auth.role() = 'authenticated' and name like auth.uid()::text || '.%');
