/**
 * Issue #592: Account Deletion Flow - Improved Data Export Function.
 *
 * The handler lives in handler.ts so tests can import it without starting a
 * server; this file only wires it up, exactly as before (issue #735).
 */

import { createSupabaseClient, handleRequest } from './handler.ts';

Deno.serve((req) => handleRequest(req, { supabase: createSupabaseClient() }));
