import { createClient } from '@supabase/supabase-js';

// Avoid throwing at import-time so unrelated routes/tests (e.g. /health) can run
// without Supabase env vars. If Stellar routes are called without valid env,
// Supabase will fail at request time.
const supabaseUrl =
  process.env.SUPABASE_URL ?? 'http://localhost:54321';
const serviceRoleKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ?? 'dummy-service-role-key';

export const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

