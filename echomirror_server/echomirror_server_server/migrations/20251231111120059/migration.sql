BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "scheduled_sessions" (
    "id" bigserial PRIMARY KEY,
    "hostId" text NOT NULL,
    "hostName" text NOT NULL,
    "hostAvatarUrl" text,
    "title" text NOT NULL,
    "description" text,
    "scheduledTime" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "isVideoEnabled" boolean NOT NULL,
    "isVoiceOnly" boolean NOT NULL,
    "isNotified" boolean NOT NULL DEFAULT false,
    "isCancelled" boolean NOT NULL DEFAULT false,
    "actualSessionId" text
);

-- Indexes
CREATE INDEX "scheduled_time_idx" ON "scheduled_sessions" USING btree ("scheduledTime");
CREATE INDEX "scheduled_host_id_idx" ON "scheduled_sessions" USING btree ("hostId");
CREATE INDEX "is_notified_idx" ON "scheduled_sessions" USING btree ("isNotified");


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20251231111120059', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251231111120059', "timestamp" = now();

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
