// deno-lint-ignore-file no-import-prefix
import { serve } from 'https://deno.land/std@0.192.0/http/server.ts';
import { handleRequest, type SaveFutureLetterDeps } from './handler.ts';

/**
 * Runtime wiring for `save-future-letter`: the pure handler lives in
 * `handler.ts` (the offline tests import it with fakes); this file only starts
 * the server and supplies the real fetch/env/clock, exactly as before
 * (issue #735).
 */

function createRuntimeDeps(): SaveFutureLetterDeps {
  return {
    fetch,
    env: (name) => {
      const value = Deno.env.get(name);
      return value === undefined ? undefined : value;
    },
  };
}

serve(async (req) => await handleRequest(req, createRuntimeDeps()));

