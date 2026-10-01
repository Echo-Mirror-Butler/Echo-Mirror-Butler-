/**
 * The digest unsubscribe secret, in one place (Issue #762).
 *
 * `unsubscribe-digest` and `send-weekly-digest` must sign and verify with the
 * *same* secret, and that secret must never fall back to a built-in default: the
 * previous `Deno.env.get('UNSUBSCRIBE_SECRET') ?? 'default-unsubscribe-secret'`
 * meant that a fresh deploy, a preview environment or a rotation that missed
 * this one variable silently switched both functions to a publicly visible
 * string — and anyone could then forge a valid unsubscribe link.
 *
 * Resolution now fails loudly, and it also refuses the historical default value
 * so a copied `.env` cannot quietly re-introduce it.
 */

export const UNSUBSCRIBE_SECRET_ENV = "UNSUBSCRIBE_SECRET";

/** The value that used to be the silent fallback; never acceptable as a secret. */
export const KNOWN_WEAK_UNSUBSCRIBE_SECRET = "default-unsubscribe-secret";

export class UnsubscribeSecretMissingError extends Error {
  constructor(detail: string) {
    super(
      `${UNSUBSCRIBE_SECRET_ENV} is not usable: ${detail}. ` +
        "Set it with `supabase secrets set UNSUBSCRIBE_SECRET=<random value>` — " +
        "digest unsubscribe links are HMAC-signed with it, so a default value " +
        "would let anyone forge them.",
    );
    this.name = "UnsubscribeSecretMissingError";
  }
}

export interface EnvLike {
  get(key: string): string | undefined;
}

/**
 * The configured secret. `override` exists for tests and for callers that
 * already resolved it; it is validated the same way.
 */
export function resolveUnsubscribeSecret(
  env: EnvLike = Deno.env,
  override?: string,
): string {
  const secret = override ?? env.get(UNSUBSCRIBE_SECRET_ENV);

  if (secret === undefined || secret === null || secret.trim() === "") {
    throw new UnsubscribeSecretMissingError("it is unset or empty");
  }
  if (secret === KNOWN_WEAK_UNSUBSCRIBE_SECRET) {
    throw new UnsubscribeSecretMissingError(
      `it is still the historical default ("${KNOWN_WEAK_UNSUBSCRIBE_SECRET}")`,
    );
  }
  return secret;
}

/**
 * Log-only start-up assertion. The request path already fails closed, but a
 * misconfigured deployment should say so in the logs at boot rather than only
 * when the first user clicks an unsubscribe link.
 */
export function assertUnsubscribeSecretConfigured(
  log: (message: string) => void,
  env: EnvLike = Deno.env,
): boolean {
  try {
    resolveUnsubscribeSecret(env);
    return true;
  } catch (error) {
    log(error instanceof Error ? error.message : String(error));
    return false;
  }
} // deno-lint-ignore-file no-import-prefix
