-- Create table for tracking recommendation actions
create table if not exists public.insight_actions (
  insight_id uuid not null references public.ai_insights(id) on delete cascade,
  recommendation_index integer not null,
  followed boolean not null,
  created_at timestamptz not null default now(),
  primary key (insight_id, recommendation_index)
);

-- Enable RLS on insight_actions
alter table public.insight_actions enable row level security;

-- Policies for insight_actions
create policy "Users can view own insight actions"
  on public.insight_actions for select
  using (
    exists (
      select 1 from public.ai_insights
      where public.ai_insights.id = public.insight_actions.insight_id
        and public.ai_insights.user_id = auth.uid()
    )
  );

create policy "Users can insert own insight actions"
  on public.insight_actions for insert
  with check (
    exists (
      select 1 from public.ai_insights
      where public.ai_insights.id = public.insight_actions.insight_id
        and public.ai_insights.user_id = auth.uid()
    )
  );

create policy "Users can update own insight actions"
  on public.insight_actions for update
  using (
    exists (
      select 1 from public.ai_insights
      where public.ai_insights.id = public.insight_actions.insight_id
        and public.ai_insights.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.ai_insights
      where public.ai_insights.id = public.insight_actions.insight_id
        and public.ai_insights.user_id = auth.uid()
    )
  );

create policy "Users can delete own insight actions"
  on public.insight_actions for delete
  using (
    exists (
      select 1 from public.ai_insights
      where public.ai_insights.id = public.insight_actions.insight_id
        and public.ai_insights.user_id = auth.uid()
    )
  );

-- Update ai_insights table with mood_score and personal_note
alter table public.ai_insights
add column if not exists mood_score int check (mood_score between 1 and 5),
add column if not exists personal_note text;

-- Add update policy to ai_insights
create policy "Users can update own ai insights"
  on public.ai_insights for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
