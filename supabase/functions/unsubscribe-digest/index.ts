import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleRequest } from "./handler.ts";

// The handler lives in handler.ts so tests can import it without starting a
// server; this file only wires it up (issue #735).
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve((req) =>
  handleRequest(req, { supabase: supabase as unknown as { from: (table: string) => unknown }, secret: Deno.env.get("UNSUBSCRIBE_SECRET") })
);
