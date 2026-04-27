-- Create storage buckets for videos and images
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values 
  ('videos', 'videos', true, 409600, ARRAY['video/mp4', 'video/quicktime', 'video/webm']),
  ('images', 'images', true, 409600, ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']);

-- Enable public read access for videos
create policy "Public Access to Videos"
  on storage.objects for select
  using ( bucket_id = 'videos' );

-- Enable public read access for images
create policy "Public Access to Images"
  on storage.objects for select
  using ( bucket_id = 'images' );

-- Allow authenticated users to insert videos
create policy "Authenticated users can upload videos"
  on storage.objects for insert
  with check ( bucket_id = 'videos' and auth.role() = 'authenticated' );

-- Allow authenticated users to insert images
create policy "Authenticated users can upload images"
  on storage.objects for insert
  with check ( bucket_id = 'images' and auth.role() = 'authenticated' );

-- Keep realtime publication setup idempotent for clean resets.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mood_pins'
  ) then
    alter publication supabase_realtime add table public.mood_pins;
  end if;
end
$$;
