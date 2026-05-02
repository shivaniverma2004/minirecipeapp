-- Run this in Supabase SQL Editor if you get RLS errors on recipe insert
-- or avatar upload, usually due to UUID text case (Swift vs Postgres).

-- Case-insensitive author checks on recipes
drop policy if exists "recipes_insert" on public.recipes;
create policy "recipes_insert"
  on public.recipes for insert
  with check (
    auth.uid() is not null
    and lower(trim(author_id)) = lower(auth.uid()::text)
  );

drop policy if exists "recipes_author_update" on public.recipes;
create policy "recipes_author_update"
  on public.recipes for update
  using (lower(trim(author_id)) = lower(auth.uid()::text))
  with check (lower(trim(author_id)) = lower(auth.uid()::text));

drop policy if exists "recipes_author_delete" on public.recipes;
create policy "recipes_author_delete"
  on public.recipes for delete
  using (lower(trim(author_id)) = lower(auth.uid()::text));

-- Avatar object key must match user id (case-insensitive compare in policy)
drop policy if exists "avatars_auth_upload_own" on storage.objects;
drop policy if exists "avatars_auth_update_own" on storage.objects;
drop policy if exists "avatars_auth_delete_own" on storage.objects;

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

-- Allow users to create their own profile row if the trigger missed
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);
