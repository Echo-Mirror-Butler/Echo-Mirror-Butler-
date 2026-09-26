import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { handleRequest } from "./handler.ts";

// The handler lives in handler.ts so tests can import it without starting a
// server; this file only wires it up, exactly as before (issue #735).
serve((req) => handleRequest(req, { fetch, env: (name) => Deno.env.get(name) }));
