/**
 * Guard against secret fallbacks reappearing (Issue #762).
 *
 * The bug was `Deno.env.get('UNSUBSCRIBE_SECRET') ?? 'default-unsubscribe-secret'`:
 * a missing environment variable silently switched two functions to a publicly
 * visible HMAC key, so anyone could forge an unsubscribe link. The request paths
 * now fail closed and a start-up assertion logs the problem, but the *pattern*
 * could come back in the next function someone writes — so this test fails CI
 * when a fallback literal is used for a secret-shaped environment variable.
 *
 * `?? ''` is deliberate and allowed: an empty value fails loudly downstream
 * instead of substituting a known-weak default. Only non-empty literals are
 * rejected.
 *
 * Run: deno test --allow-all supabase/functions/test_runner.ts
 */

// deno-lint-ignore-file no-import-prefix
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";

const FUNCTIONS_DIR = new URL("./", import.meta.url);

/** Env names that must never have a literal fallback. */
const SECRET_LIKE = /(SECRET|PASSWORD|_KEY|_TOKEN|_CERT)/i;

/** `Deno.env.get('NAME') ?? 'literal'` and the `||` variant. */
const FALLBACK_PATTERN =
  /Deno\.env\.get\(\s*["']([A-Z0-9_]+)["']\s*\)\s*(?:\?\?|\|\|)\s*(["'])(.*?)\2/gs;

async function functionSources(): Promise<
  Array<{ path: string; text: string }>
> {
  const sources: Array<{ path: string; text: string }> = [];

  for await (const entry of Deno.readDir(FUNCTIONS_DIR)) {
    if (!entry.isDirectory) continue;
    const indexPath = new URL(`${entry.name}/index.ts`, FUNCTIONS_DIR);
    let text: string;
    try {
      text = await Deno.readTextFile(indexPath);
    } catch {
      continue; // directories like _shared have no index.ts
    }
    sources.push({ path: `${entry.name}/index.ts`, text });
  }

  return sources;
}

Deno.test("no Edge Function falls back to a literal value for a secret env var", async () => {
  const offenders: string[] = [];

  for (const { path, text } of await functionSources()) {
    for (const match of text.matchAll(FALLBACK_PATTERN)) {
      const [, name, , literal] = match;
      if (!SECRET_LIKE.test(name)) continue;
      if (literal.trim() === "") continue; // empty means "fail loudly downstream"
      const line = text.slice(0, match.index).split("\n").length;
      offenders.push(`${path}:${line} — ${name} falls back to '${literal}'`);
    }
  }

  assertEquals(
    offenders.length,
    0,
    `Secret environment variables must not have literal fallbacks:\n  ${
      offenders.join("\n  ")
    }`,
  );
});

Deno.test("both digest functions resolve the unsubscribe secret from the shared module", async () => {
  for (const name of ["unsubscribe-digest", "send-weekly-digest"]) {
    const text = await Deno.readTextFile(
      new URL(`${name}/index.ts`, FUNCTIONS_DIR),
    );
    assert(
      text.includes("_shared/unsubscribe-hmac.ts"),
      `${name} must use _shared/unsubscribe-hmac.ts instead of reading the env var itself`,
    );
    assert(
      !text.includes("default-unsubscribe-secret"),
      `${name} still mentions the historical default secret`,
    );
  }
});
