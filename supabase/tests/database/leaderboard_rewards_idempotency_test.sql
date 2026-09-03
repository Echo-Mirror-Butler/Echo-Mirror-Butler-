-- Contract test for leaderboard settlement idempotency.
-- Run against a database with the migrations applied.

BEGIN;

DO $$
DECLARE
  test_user uuid := '77777777-7777-7777-7777-777777777777';
  reward_reason text := 'leaderboard_bonus_rank_1_week_2026-08-24';
BEGIN
  INSERT INTO auth.users (id, email)
  VALUES (test_user, 'leaderboard-idempotency@example.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.echo_rewards (user_id, amount, reason)
  VALUES (test_user, 100, reward_reason);

  BEGIN
    INSERT INTO public.echo_rewards (user_id, amount, reason)
    VALUES (test_user, 100, reward_reason);
    RAISE EXCEPTION 'Duplicate leaderboard reward was accepted';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$$;

ROLLBACK;
-- Run with: supabase test db

create extension if not exists pgtap with schema extensions;

select plan(2);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values (
  '77777777-7777-7777-7777-777777777777',
  'authenticated',
  'authenticated',
  'leaderboard-idempotency@example.test',
  now(),
  now()
)
on conflict (id) do nothing;

insert into public.echo_rewards (user_id, amount, reason)
values (
  '77777777-7777-7777-7777-777777777777',
  100,
  'leaderboard_bonus_rank_1_week_2026-08-24'
);

select ok(
  (
    select count(*) = 1
    from public.echo_rewards
    where user_id = '77777777-7777-7777-7777-777777777777'
      and reason = 'leaderboard_bonus_rank_1_week_2026-08-24'
  ),
  'initial leaderboard reward is inserted'
);

select throws_ok(
  $$insert into public.echo_rewards (user_id, amount, reason)
    values ('77777777-7777-7777-7777-777777777777', 100, 'leaderboard_bonus_rank_1_week_2026-08-24')$$,
  '23505',
  null,
  'duplicate leaderboard reward for the same user/reason is rejected'
);

select * from finish();
