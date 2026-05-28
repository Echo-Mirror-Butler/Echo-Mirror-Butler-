create extension if not exists pgtap with schema extensions;

select plan(7);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  ('00000000-0000-4000-8000-000000000101', 'authenticated', 'authenticated', 'streak-empty@example.test', now(), now()),
  ('00000000-0000-4000-8000-000000000102', 'authenticated', 'authenticated', 'streak-one@example.test', now(), now()),
  ('00000000-0000-4000-8000-000000000103', 'authenticated', 'authenticated', 'streak-four@example.test', now(), now()),
  ('00000000-0000-4000-8000-000000000104', 'authenticated', 'authenticated', 'streak-gap@example.test', now(), now()),
  ('00000000-0000-4000-8000-000000000105', 'authenticated', 'authenticated', 'reward@example.test', now(), now());

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_wallets'
      and column_name = 'encrypted_secret'
  ) then
    insert into public.user_wallets (user_id, public_key, encrypted_secret, balance)
    values ('00000000-0000-4000-8000-000000000105', 'GTESTREWARDPUBLICKEY', 'encrypted-test-secret', 0);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_wallets'
      and column_name = 'secret_key'
  ) then
    insert into public.user_wallets (user_id, public_key, secret_key, balance)
    values ('00000000-0000-4000-8000-000000000105', 'GTESTREWARDPUBLICKEY', 'secret-test-key', 0);
  else
    insert into public.user_wallets (user_id, public_key, balance)
    values ('00000000-0000-4000-8000-000000000105', 'GTESTREWARDPUBLICKEY', 0);
  end if;
end $$;

select is(
  public.get_current_streak('00000000-0000-4000-8000-000000000101'),
  0,
  'get_current_streak returns 0 when the user has no mood logs'
);

insert into public.mood_logs (user_id, mood, created_at)
values ('00000000-0000-4000-8000-000000000102', 'calm', current_date);

select is(
  public.get_current_streak('00000000-0000-4000-8000-000000000102'),
  1,
  'get_current_streak returns 1 for one log today'
);

insert into public.mood_logs (user_id, mood, created_at)
select
  '00000000-0000-4000-8000-000000000103',
  'steady',
  current_date - (offset_days || ' days')::interval
from generate_series(0, 3) as offset_days;

select is(
  public.get_current_streak('00000000-0000-4000-8000-000000000103'),
  4,
  'get_current_streak returns N for N consecutive days ending today'
);

insert into public.mood_logs (user_id, mood, created_at)
values
  ('00000000-0000-4000-8000-000000000104', 'low', current_date - interval '2 days'),
  ('00000000-0000-4000-8000-000000000104', 'low', current_date - interval '3 days');

select is(
  public.get_current_streak('00000000-0000-4000-8000-000000000104'),
  0,
  'get_current_streak resets to 0 when the latest streak does not reach today or yesterday'
);

insert into public.mood_logs (user_id, mood, created_at)
values ('00000000-0000-4000-8000-000000000105', 'good', current_date);

select is(
  (select balance::numeric from public.user_wallets where user_id = '00000000-0000-4000-8000-000000000105'),
  1::numeric,
  'mood log insert increments the user wallet ECHO balance by the daily reward'
);

insert into public.mood_logs (user_id, mood, created_at)
values ('00000000-0000-4000-8000-000000000105', 'great', current_date + interval '1 hour');

select is(
  (select balance::numeric from public.user_wallets where user_id = '00000000-0000-4000-8000-000000000105'),
  1::numeric,
  'duplicate mood logs on the same day do not double-credit ECHO'
);

delete from public.mood_logs
where user_id = '00000000-0000-4000-8000-000000000105'
  and mood = 'good';

select is(
  (select balance::numeric from public.user_wallets where user_id = '00000000-0000-4000-8000-000000000105'),
  1::numeric,
  'deleting a mood log does not subtract non-refundable ECHO rewards'
);

select * from finish();
