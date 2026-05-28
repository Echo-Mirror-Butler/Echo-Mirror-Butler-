create or replace function public.get_current_streak(user_id uuid)
returns integer
language sql
stable
security invoker
as $$
  select coalesce((public.calculate_streak($1)->>'current_streak')::integer, 0);
$$;

alter table public.user_wallets
  add column if not exists balance integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.grant_echo_reward()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_today date := current_date;
    v_reward_count int;
    v_current_streak int;
    v_reward_amount int := 1;
    v_reason text := 'daily_mood_log';
begin
    if new.user_id is null then
        return new;
    end if;

    select count(*)
    into v_reward_count
    from public.echo_rewards
    where user_id = new.user_id
      and created_at::date = v_today
      and reason in ('daily_mood_log', '7_day_streak_bonus');

    if v_reward_count > 0 then
        return new;
    end if;

    v_current_streak := public.get_current_streak(new.user_id);

    if v_current_streak > 0 and v_current_streak % 7 = 0 then
        v_reward_amount := 5;
        v_reason := '7_day_streak_bonus';
    end if;

    insert into public.echo_rewards (user_id, amount, reason)
    values (new.user_id, v_reward_amount, v_reason);

    update public.user_wallets
    set balance = balance + v_reward_amount,
        updated_at = now()
    where user_id = new.user_id;

    return new;
end;
$$;
