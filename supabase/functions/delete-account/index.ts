import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';
import { handleRequest } from './handler.ts';

// The handler lives in handler.ts so tests can import it without starting a
// server; this file only wires it up (issue #735).
const logger = createLogger('delete-account');

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const supabase =
    supabaseUrl && supabaseKey
      ? (createClient(supabaseUrl, supabaseKey) as unknown as Parameters<typeof handleRequest>[1]['supabase'])
      : null;
  return handleRequest(req, { supabase, logger });
});
