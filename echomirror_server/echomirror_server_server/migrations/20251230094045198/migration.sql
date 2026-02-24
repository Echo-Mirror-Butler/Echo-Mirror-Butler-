BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "video_sessions" (
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

-- Indexes
CREATE INDEX "created_at_idx" ON "video_sessions" USING btree ("createdAt");
CREATE INDEX "expires_at_idx" ON "video_sessions" USING btree ("expiresAt");
CREATE INDEX "is_active_idx" ON "video_sessions" USING btree ("isActive");
CREATE INDEX "host_id_idx" ON "video_sessions" USING btree ("hostId");


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20251230094045198', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251230094045198', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20251208110333922-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110333922-v3-0-0', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20251208110420531-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110420531-v3-0-0', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20251208110412389-v3-0-0', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251208110412389-v3-0-0', "timestamp" = now();


COMMIT;
