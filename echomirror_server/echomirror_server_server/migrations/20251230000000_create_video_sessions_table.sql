-- Create video_sessions table for video/voice call sessions
CREATE TABLE IF NOT EXISTS "video_sessions" (
  "id" bigserial PRIMARY KEY,
  "hostId" text NOT NULL,
  "hostName" text NOT NULL,
  "hostAvatarUrl" text,
  "title" text NOT NULL,
  "createdAt" timestamp without time zone NOT NULL,
  "expiresAt" timestamp without time zone NOT NULL,
  "participantCount" bigint NOT NULL,
  "isVideoEnabled" boolean NOT NULL,
  "isVoiceOnly" boolean NOT NULL,
  "isActive" boolean NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS "video_sessions_created_at_idx" ON "video_sessions" ("createdAt" DESC);
CREATE INDEX IF NOT EXISTS "video_sessions_expires_at_idx" ON "video_sessions" ("expiresAt");
CREATE INDEX IF NOT EXISTS "video_sessions_is_active_idx" ON "video_sessions" ("isActive");
CREATE INDEX IF NOT EXISTS "video_sessions_host_id_idx" ON "video_sessions" ("hostId");

