import { createClient } from "npm:@supabase/supabase-js@2";
import { handleRequest } from "./handler.ts";

// The handler lives in handler.ts so tests can import it without starting a
// server; this file only wires it up (issue #735).
Deno.serve((req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase =
    supabaseUrl && serviceRoleKey
      ? (createClient(supabaseUrl, serviceRoleKey, {
          auth: { autoRefreshToken: false, persistSession: false },
        }) as unknown as Parameters<typeof handleRequest>[1]["supabase"])
      : null;
  return handleRequest(req, { supabase });
});
