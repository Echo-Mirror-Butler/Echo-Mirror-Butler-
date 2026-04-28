-- ============================================================
-- Add user_id to mood_pins for ownership tracking (#260)
-- This enables the MyPinsSidebar to filter pins by the
-- current user without joining user_mood_pins every time,
-- and allows a proper RLS delete policy.
-- ============================================================

-- 1. Add the column (nullable so existing rows are not broken)
alter table public.mood_pins
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- 2. Create an index for the common sidebar query pattern
create index if not exists idx_mood_pins_user
  on public.mood_pins(user_id);

-- 3. Allow authenticated users to delete their own pins
create policy "Users can delete own mood pins"
  on public.mood_pins for delete
  using (auth.uid() = user_id);

-- 4. Ensure the realtime publication includes mood_pins
--    (idempotent guard — also done in 20260323000000 migration)
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mood_pins'
  ) then
    alter publication supabase_realtime add table public.mood_pins;
  end if;
end
$$;
