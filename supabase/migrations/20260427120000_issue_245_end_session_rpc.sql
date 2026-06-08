-- Add end_session RPC to mark video sessions as inactive when host leaves
create or replace function public.end_session(session_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.video_sessions
  set is_active = false
  where id = session_id
    and host_id = auth.uid();
end;
$$;
