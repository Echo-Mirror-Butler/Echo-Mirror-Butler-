-- Contract test for leaderboard settlement idempotency.
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
