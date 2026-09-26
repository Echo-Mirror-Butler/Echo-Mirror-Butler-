/**
 * Request handler for `request-password-reset`, separated from `index.ts` so
 * it can be called without starting a server, with the Supabase admin client
 * and crypto injected (issue #735).
 *
 * Always returns a generic success payload so callers cannot enumerate
 * whether an email is registered. Rate-limits by email hash and client IP.
 */

export const GENERIC_SUCCESS = {
  success: true,
  message: "If an account exists for that email, a password reset link has been sent.",
};

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function rateLimited(): Response {
  return jsonResponse(
    {
      error: "rate_limit_exceeded",
      message: "Too many reset attempts. Please try again later.",
      retry_after_seconds: 3600,
    },
    429,
  );
}

export interface PasswordResetSupabase {
  rpc: (name: string, args?: unknown) => PromiseLike<{ data?: unknown; error: { message: string } | null }>;
  auth: {
    resetPasswordForEmail: (
      email: string,
      options?: { redirectTo?: string },
    ) => PromiseLike<{ error: { message: string } | null }>;
  };
}

export interface PasswordResetDeps {
  /** The service-role admin client; `null` stands for a misconfigured runtime. */
  supabase: PasswordResetSupabase | null;
  /** Injectable so tests can run without the runtime crypto. */
  crypto?: Crypto;
}

export async function sha256Hex(value: string, cryptoImpl: Crypto = crypto): Promise<string> {
  const data = new TextEncoder().encode(value);
  const hash = await cryptoImpl.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0]?.trim() || "unknown";
  }
  return req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") || "unknown";
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export async function handleRequest(req: Request, deps: PasswordResetDeps): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: jsonHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!deps.supabase) {
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }
  const admin = deps.supabase;

  // A body that is not valid JSON, or not an object at all (null, a number,
  // an array), falls into the generic path instead of throwing a 500.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }
  if (typeof body !== "object" || body === null) body = {};
  const { email: rawEmail, redirectTo: rawRedirectTo } = body as { email?: unknown; redirectTo?: unknown };

  const email = (typeof rawEmail === "string" ? rawEmail : "").trim().toLowerCase();
  if (!email || !isValidEmail(email)) {
    // Generic response — do not reveal validation details that aid probing
    return jsonResponse(GENERIC_SUCCESS);
  }

  const emailKey = `email:${await sha256Hex(email, deps.crypto)}`;
  const ipKey = `ip:${clientIp(req)}`;

  // 3 resets per email / hour
  const { data: emailAllowed, error: emailLimitErr } = await admin.rpc("check_auth_rate_limit", {
    p_key: emailKey,
    p_action: "password_reset",
    p_max_count: 3,
    p_window_minutes: 60,
  });

  if (emailLimitErr) {
    console.error("check_auth_rate_limit email error", emailLimitErr);
    // A broken limiter is a server fault, not an exhausted quota: reporting it
    // as 429 tells the client to retry in an hour when the real problem is
    // inside our own stack.
    return jsonResponse({ error: "internal_error", message: "Unable to process the request." }, 500);
  }

  if (emailAllowed === false) {
    return rateLimited();
  }

  // 10 resets per IP / hour
  const { data: ipAllowed, error: ipLimitErr } = await admin.rpc("check_auth_rate_limit", {
    p_key: ipKey,
    p_action: "password_reset",
    p_max_count: 10,
    p_window_minutes: 60,
  });

  if (ipLimitErr) {
    console.error("check_auth_rate_limit ip error", ipLimitErr);
    // Previously an IP-limiter failure was logged and ignored (fail-open), so
    // a broken limiter silently disabled the per-IP cap. Fail closed: no
    // quota signal means we do not send reset email on this request.
    return jsonResponse({ error: "internal_error", message: "Unable to process the request." }, 500);
  }

  if (ipAllowed === false) {
    return rateLimited();
  }

  // The redirect target must be https: an origin-echo or a client-supplied
  // "http://…" value would land the reset token on an attacker-controlled
  // page. Non-https origins/redirects fall back to the platform default.
  let redirectTo: string | undefined;
  if (typeof rawRedirectTo === "string" && rawRedirectTo.startsWith("https://")) {
    redirectTo = rawRedirectTo;
  } else {
    const origin = req.headers.get("origin") ?? "";
    if (origin.startsWith("https://")) redirectTo = `${origin}/update-password`;
  }

  // Fire reset; ignore "user not found" style errors for anti-enumeration,
  // but a throw (network/auth-service outage) must NOT masquerade as success.
  try {
    const { error } = await admin.auth.resetPasswordForEmail(email, { redirectTo });
    if (error) {
      console.error("resetPasswordForEmail error", error.message);
    }
  } catch (err) {
    console.error("resetPasswordForEmail threw", err);
    return jsonResponse({ error: "service_unavailable", message: "Unable to send the email right now." }, 502);
  }

  return jsonResponse(GENERIC_SUCCESS);
}
