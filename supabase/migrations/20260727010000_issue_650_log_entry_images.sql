-- ============================================================
-- Issue #650: optional image attachment on mood log entries
-- ============================================================

alter table public.log_entries
  add column if not exists image_path text;

-- Private bucket: images are NOT publicly readable, only the
-- owning user can read/write their own files (RLS below).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('log-images', 'log-images', false, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  create policy "Users can read own log images"
    on storage.objects for select
    using (bucket_id = 'log-images' and auth.uid()::text = (storage.foldername(name))[1]);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "Users can upload own log images"
    on storage.objects for insert
    with check (bucket_id = 'log-images' and auth.uid()::text = (storage.foldername(name))[1]);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "Users can update own log images"
    on storage.objects for update
    using (bucket_id = 'log-images' and auth.uid()::text = (storage.foldername(name))[1])
    with check (bucket_id = 'log-images' and auth.uid()::text = (storage.foldername(name))[1]);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "Users can delete own log images"
    on storage.objects for delete
    using (bucket_id = 'log-images' and auth.uid()::text = (storage.foldername(name))[1]);
exception
  when duplicate_object then null;
end $$;
