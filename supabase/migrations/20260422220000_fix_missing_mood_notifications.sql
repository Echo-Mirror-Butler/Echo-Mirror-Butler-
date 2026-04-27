-- ============================================================
-- Fix: Missing mood_comment_notifications table and trigger
-- ============================================================

-- 1. Create the notifications table if it doesn't exist
create table if not exists public.mood_comment_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood_pin_id uuid not null references public.mood_pins(id) on delete cascade,
  comment_id uuid not null references public.mood_pin_comments(id) on delete cascade,
  comment_text text, -- Nullable as per Issue #84
  sentiment text,    -- Nullable as per Issue #84
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- 2. Add index for performance
create index if not exists idx_notifications_user on public.mood_comment_notifications(user_id, is_read);

-- 3. Enable RLS
alter table public.mood_comment_notifications enable row level security;

-- 4. Rebuild policies (drop if exists first)
drop policy if exists "Users can read own notifications" on public.mood_comment_notifications;
drop policy if exists "Users can update own notifications" on public.mood_comment_notifications;
drop policy if exists "Users can delete own notifications" on public.mood_comment_notifications;

create policy "Users can read own notifications"
  on public.mood_comment_notifications for select
  using (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.mood_comment_notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own notifications"
  on public.mood_comment_notifications for delete
  using (auth.uid() = user_id);

-- 5. Trigger Function to automatically create notifications
create or replace function public.on_mood_comment_added()
returns trigger
language plpgsql
security definer
as $$
declare
    v_recipient_id uuid;
    v_sentiment text;
begin
    -- Find the owner of the mood pin via the user_mood_pins lookup table
    select user_id into v_recipient_id
    from public.user_mood_pins
    where mood_pin_id = new.mood_pin_id;

    -- Only notify if:
    -- 1. The owner exists (pins can be truly anonymous if not in user_mood_pins)
    -- 2. The owner is NOT the person who just commented
    if v_recipient_id is not null and v_recipient_id != new.user_id then
        -- Get the sentiment of the pin for the notification preview
        select sentiment into v_sentiment
        from public.mood_pins
        where id = new.mood_pin_id;

        insert into public.mood_comment_notifications (
            user_id,
            mood_pin_id,
            comment_id,
            comment_text,
            sentiment,
            is_read
        ) values (
            v_recipient_id,
            new.mood_pin_id,
            new.id,
            new.text,
            coalesce(v_sentiment, 'neutral'),
            false
        );
    end if;
    return new;
end;
$$;

-- 6. Create the trigger
drop trigger if exists tr_mood_comment_added on public.mood_pin_comments;
create trigger tr_mood_comment_added
  after insert on public.mood_pin_comments
  for each row execute function public.on_mood_comment_added();

-- 7. Enable Realtime for the notifications table
-- Check if the table is already in the publication to avoid errors
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'mood_comment_notifications'
  ) then
    alter publication supabase_realtime add table public.mood_comment_notifications;
  end if;
end $$;
