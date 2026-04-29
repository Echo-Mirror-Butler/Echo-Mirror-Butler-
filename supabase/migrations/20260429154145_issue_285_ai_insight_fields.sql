-- Issue #285: Add AI fields for calming message and music recommendations
alter table public.ai_insights
add column if not exists calming_message text,
add column if not exists music_recommendations jsonb default '[]';
