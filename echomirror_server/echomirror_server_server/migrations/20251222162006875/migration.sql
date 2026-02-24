BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "mood_comment_notifications" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "moodPinId" bigint NOT NULL,
    "commentId" bigint NOT NULL,
    "commentText" text NOT NULL,
    "sentiment" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "isRead" boolean NOT NULL
);

-- Indexes
CREATE INDEX "mood_notification_user_idx" ON "mood_comment_notifications" USING btree ("userId");
CREATE INDEX "mood_notification_unread_idx" ON "mood_comment_notifications" USING btree ("userId", "isRead");
CREATE INDEX "mood_notification_timestamp_idx" ON "mood_comment_notifications" USING btree ("timestamp");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "mood_pin_comments" (
    "id" bigserial PRIMARY KEY,
    "moodPinId" bigint NOT NULL,
    "userId" bigint,
    "text" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "mood_pin_comment_mood_pin_idx" ON "mood_pin_comments" USING btree ("moodPinId");
CREATE INDEX "mood_pin_comment_user_idx" ON "mood_pin_comments" USING btree ("userId");
CREATE INDEX "mood_pin_comment_timestamp_idx" ON "mood_pin_comments" USING btree ("timestamp");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_mood_pins" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "moodPinId" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "user_mood_pin_user_idx" ON "user_mood_pins" USING btree ("userId");
CREATE INDEX "user_mood_pin_mood_pin_idx" ON "user_mood_pins" USING btree ("moodPinId");
CREATE UNIQUE INDEX "user_mood_pin_unique_idx" ON "user_mood_pins" USING btree ("userId", "moodPinId");


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20251222162006875', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251222162006875', "timestamp" = now();

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
