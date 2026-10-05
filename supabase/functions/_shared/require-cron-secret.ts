/**
 * require-cron-secret — shared caller check for cron-only edge functions.
 *
 * Issue #763: `cleanup-expired-stories` (and its siblings in the same
 * "runs on a schedule, currently reachable by anyone" family) exposed an
 * admin-only operation to the public internet. This module is the one place
 * that decides whether a request carries the credential the scheduler uses, so
 * the check is written once instead of drifting per function.
 *
 * Rules:
 *   - the secret comes from `CRON_SECRET` only — there is **no** fallback, a
 *     built-in default would be a publicly known key (the failure mode #762
 *     fixed in `unsubscribe-digest`);
 *   - a deployment without the secret **fails closed**: the function answers
 *     500 and does no work, it never degrades to "no check";
 *   - the presented value is compared in constant time, and is accepted either
 *     as `Authorization: Bearer <secret>` (what `pg_cron` + `net.http_post`
 *     sends most naturally) or as `x-cron-secret: <secret>`.
 */

export interface EnvLike {
  get(key: string): string | undefined;
}

export const CRON_SECRET_ENV = "CRON_SECRET";
export const CRON_SECRET_HEADER = "x-cron-secret";

/** Thrown when the deployment has no `CRON_SECRET` configured. */
export class CronSecretMissingError extends Error {
  constructor(message = `${CRON_SECRET_ENV} is not configured`) {
    super(message);
    this.name = "CronSecretMissingError";
  }
}

/** The configured secret, or a thrown error — never a default. */
export function resolveCronSecret(env: EnvLike = Deno.env, override?: string): string {
  const secret = (override ?? env.get(CRON_SECRET_ENV) ?? "").trim();
  if (!secret) throw new CronSecretMissingError();
  return secret;
}

/**
 * Boot-time check, so a misconfigured deployment says so in the logs instead of
 * only on the first scheduled call. Returns whether the secret is present.
 */
export function assertCronSecretConfigured(
  onMissing: (message: string) => void,
  env: EnvLike = Deno.env,
): boolean {
  try {
    resolveCronSecret(env);
    return true;
  } catch (error) {
    onMissing((error as Error).message);
    return false;
  }
}

/** The credential the caller presented, or null when there is none. */
export function extractPresentedCronSecret(req: Request): string | null {
  const header = req.headers.get(CRON_SECRET_HEADER);
  if (header && header.trim()) return header.trim();

  const authorization = req.headers.get("authorization");
  if (!authorization) return null;

  const match = /^Bearer\s+(.+)$/i.exec(authorization.trim());
  const token = match?.[1]?.trim();
  return token ? token : null;
}

/**
 * Length-independent comparison: every byte of both values is read, so a
 * partially correct secret does not shorten the work (a timing oracle).
 */
export function secretsMatch(presented: string, expected: string): boolean {
  const a = new TextEncoder().encode(presented);
  const b = new TextEncoder().encode(expected);

  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);

  for (let i = 0; i < length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }

  return diff === 0;
}

export type CronAuthorization =
  | { ok: true }
  | { ok: false; status: number; message: string };

/**
 * Decide whether `req` may run the cron job. Returns the denial — with the
 * status the caller should see — instead of throwing, so a handler can
 * `const denial = authorizeCronRequest(req); if (!denial.ok) return …`.
 */
export function authorizeCronRequest(
  req: Request,
  env: EnvLike = Deno.env,
  secretOverride?: string,
): CronAuthorization {
  let expected: string;
  try {
    expected = resolveCronSecret(env, secretOverride);
  } catch (error) {
    return { ok: false, status: 500, message: (error as Error).message };
  }

  const presented = extractPresentedCronSecret(req);
  if (!presented) {
    return {
      ok: false,
      status: 401,
      message: `Missing scheduler credential (send it as ${CRON_SECRET_HEADER} or Authorization: Bearer).`,
    };
  }

  if (!secretsMatch(presented, expected)) {
    return { ok: false, status: 401, message: "Invalid scheduler credential." };
  }

  return { ok: true };
}

/** `Response` for a denied request, or null when the request may proceed. */
export function cronDenialResponse(
  req: Request,
  env: EnvLike = Deno.env,
  secretOverride?: string,
): Response | null {
  const result = authorizeCronRequest(req, env, secretOverride);
  if (result.ok) return null;

  return new Response(JSON.stringify({ error: result.message }), {
    status: result.status,
    headers: { "Content-Type": "application/json" },
  });
}
