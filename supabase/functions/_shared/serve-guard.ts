/**
 * Should this module bind the HTTP server?
 *
 * Every Edge Function calls `serve()` / `Deno.serve()` at the top level, which is
 * correct when the file *is* the running function — but `test_runner.ts` imports
 * the function modules to reach their handlers, so the runner bound the same port
 * once per function and died with `AddrInUse: Address already in use (os error 98)`
 * before a single test ran.
 *
 * The test runner sets `EDGE_FUNCTIONS_NO_SERVE=1` before importing the suites
 * (see `test_runner.ts`), so modules imported for testing register their exports
 * without listening. Anything else — the Edge Runtime, a local `deno run`, a
 * direct execution — leaves the variable unset and binds exactly as before.
 */
export const NO_SERVE_ENV = "EDGE_FUNCTIONS_NO_SERVE";

export function shouldServe(): boolean {
  return Deno.env.get(NO_SERVE_ENV) !== "1";
}
