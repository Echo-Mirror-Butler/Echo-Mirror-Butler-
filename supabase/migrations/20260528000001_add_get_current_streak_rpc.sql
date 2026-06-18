drop function if exists public.get_current_streak(uuid);

create or replace function public.get_current_streak(user_id uuid)
returns integer
language sql
stable
security invoker
as $$
  select coalesce((public.calculate_streak($1)->>'current_streak')::integer, 0);
$$;
