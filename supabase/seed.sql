-- ============================================================
-- EchoMirror Butler — Seed Data for Local Development
-- ============================================================
-- Note: Auth users are created via the Supabase Auth API, not SQL.
-- Contributors can sign up locally via the app or Supabase Studio.
--
-- This seeds some sample data that doesn't require a user_id,
-- so the app has content to display immediately.
-- ============================================================

-- Sample mood pins (anonymous, no user_id required)
insert into public.mood_pins (sentiment, grid_lat, grid_lon) values
  ('happy', 37.8, -122.4),
  ('calm', 37.7, -122.5),
  ('anxious', 37.9, -122.3),
  ('grateful', 37.8, -122.5),
  ('stressed', 37.7, -122.4),
  ('excited', 37.9, -122.5);

-- Sample video posts (public feed)
insert into public.video_posts (video_url, mood_tag) values
  ('https://example.com/sample-video-1.mp4', 'happy'),
  ('https://example.com/sample-video-2.mp4', 'calm'),
  ('https://example.com/sample-video-3.mp4', 'motivated');
