BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "mood_pins" (
    "id" bigserial PRIMARY KEY,
    "sentiment" text NOT NULL,
    "gridLat" double precision NOT NULL,
    "gridLon" double precision NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "mood_pin_timestamp_idx" ON "mood_pins" USING btree ("timestamp");
CREATE INDEX "mood_pin_expires_idx" ON "mood_pins" USING btree ("expiresAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "video_posts" (
    "id" bigserial PRIMARY KEY,
    "videoUrl" text NOT NULL,
    "moodTag" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "video_post_timestamp_idx" ON "video_posts" USING btree ("timestamp");
CREATE INDEX "video_post_expires_idx" ON "video_posts" USING btree ("expiresAt");


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20251219171103877', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251219171103877', "timestamp" = now();

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
