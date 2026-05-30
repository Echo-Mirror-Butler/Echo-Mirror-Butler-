-- Ensure every auth signup has a profiles row with the fields the web app expects.

alter table public.profiles
  add column if not exists echo_balance integer not null default 0,
  add column if not exists streak integer not null default 0;

insert into public.profiles (id, echo_balance, streak)
select users.id, 0, 0
from auth.users as users
left join public.profiles as profiles on profiles.id = users.id
where profiles.id is null;

update public.profiles
set
  echo_balance = coalesce(echo_balance, 0),
  streak = coalesce(streak, 0);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, echo_balance, streak)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'full_name'),
    0,
    0
  )
  on conflict (id) do update
  set
    echo_balance = coalesce(public.profiles.echo_balance, 0),
    streak = coalesce(public.profiles.streak, 0),
    display_name = coalesce(public.profiles.display_name, excluded.display_name);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
