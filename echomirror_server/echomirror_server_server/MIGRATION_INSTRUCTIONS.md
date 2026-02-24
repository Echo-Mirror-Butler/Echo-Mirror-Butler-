# How to Create the Password Reset Tokens Table

There are two ways to create the database table for password reset tokens:

## Method 1: Manual SQL Migration (Recommended for Quick Setup)

1. **Connect to your PostgreSQL database**:
   ```bash
   # If using Docker
   docker exec -it <postgres_container_name> psql -U <username> -d <database_name>
   
   # Or if using local PostgreSQL
   psql -U <username> -d <database_name>
   ```

2. **Run the SQL migration**:
   ```sql
   -- Copy and paste the contents of migrations/create_password_reset_tokens_table.sql
   CREATE TABLE IF NOT EXISTS "password_reset_tokens" (
       "id" SERIAL PRIMARY KEY,
       "email" VARCHAR(255) NOT NULL,
       "token" VARCHAR(255) NOT NULL UNIQUE,
       "expires_at" TIMESTAMP WITHOUT TIME ZONE NOT NULL,
       "created_at" TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
   );

   CREATE INDEX IF NOT EXISTS "password_reset_tokens_email_idx" 
       ON "password_reset_tokens" USING btree ("email");

   CREATE INDEX IF NOT EXISTS "password_reset_tokens_token_idx" 
       ON "password_reset_tokens" USING btree ("token");

   CREATE INDEX IF NOT EXISTS "password_reset_tokens_expires_at_idx" 
       ON "password_reset_tokens" USING btree ("expires_at");
   ```

3. **Verify the table was created**:
   ```sql
   \d password_reset_tokens
   ```

## Method 2: Using Serverpod Migration System

1. **Create a YAML model file** (already created at `lib/src/password_reset_token.yaml`)

2. **Fix any syntax errors in your endpoints** (if any)

3. **Generate the migration**:
   ```bash
   cd echomirror_server_server
   serverpod generate
   ```

4. **Apply the migration**:
   ```bash
   dart run bin/main.dart --apply-migrations
   ```

## Verification

After creating the table, you can verify it works by:

1. **Check the table exists**:
   ```sql
   SELECT * FROM password_reset_tokens LIMIT 1;
   ```

2. **Test the password reset flow** in your app

## Notes

- The table uses `IF NOT EXISTS` so it's safe to run the SQL multiple times
- Tokens expire after 1 hour (configurable in `password_reset_endpoint.dart`)
- Expired tokens should be cleaned up periodically (you can add a cleanup job)

