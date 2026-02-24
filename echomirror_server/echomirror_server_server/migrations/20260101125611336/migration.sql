BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "stories" (
    "id" bigserial PRIMARY KEY,
    "userId" text NOT NULL,
    "userName" text NOT NULL,
    "userAvatarUrl" text,
    "imageUrls" json NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL,
    "viewCount" bigint NOT NULL DEFAULT 0,
    "viewedBy" json NOT NULL,
    "isActive" boolean NOT NULL DEFAULT true
);

-- Indexes
CREATE INDEX "story_user_id_idx" ON "stories" USING btree ("userId");
CREATE INDEX "story_expires_at_idx" ON "stories" USING btree ("expiresAt");
CREATE INDEX "story_is_active_idx" ON "stories" USING btree ("isActive");


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20260101125611336', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260101125611336', "timestamp" = now();

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
