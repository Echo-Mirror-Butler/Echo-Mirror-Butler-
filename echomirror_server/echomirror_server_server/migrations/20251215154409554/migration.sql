BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "log_entries" (
    "id" bigserial PRIMARY KEY,
    "userId" text NOT NULL,
    "date" timestamp without time zone NOT NULL,
    "mood" bigint,
    "habits" json NOT NULL,
    "notes" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone
);


--
-- MIGRATION VERSION FOR echomirror_server
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('echomirror_server', '20251215154409554', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251215154409554', "timestamp" = now();

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
