/**
 * Request handler for `unsubscribe-digest`, separated from `index.ts` so it can
 * be called without starting a server, with Supabase, the signing secret and
 * crypto injected (issue #735).
 */

export const HTML_SUCCESS = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Unsubscribed</title>
</head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="background:#fff;border-radius:16px;padding:40px;text-align:center;max-width:400px;margin:20px;">
<div style="font-size:48px;">✅</div>
<h1 style="font-size:22px;color:#1a1a2e;margin:16px 0 8px;">You're unsubscribed</h1>
<p style="color:#666;font-size:14px;margin:0;line-height:1.5;">You'll no longer receive the EchoMirror weekly digest. You can re-enable it anytime in Settings.</p>
<a href="https://echomirrorbutler.vercel.app" style="display:inline-block;margin-top:24px;background:linear-gradient(135deg,#6366F1,#8B5CF6);color:#fff;text-decoration:none;padding:12px 28px;border-radius:12px;font-size:14px;font-weight:600;">Back to EchoMirror</a>
</div>
</body>
</html>`;

export const HTML_FAILED = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Unsubscribe failed</title>
</head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="background:#fff;border-radius:16px;padding:40px;text-align:center;max-width:400px;margin:20px;">
<div style="font-size:48px;">❌</div>
<h1 style="font-size:22px;color:#1a1a2e;margin:16px 0 8px;">Invalid link</h1>
<p style="color:#666;font-size:14px;margin:0;line-height:1.5;">This unsubscribe link is invalid or expired. Please try again from the email or contact support.</p>
</div>
</body>
</html>`;

const HTML_HEADERS = { "Content-Type": "text/html; charset=utf-8" };

function html(body: string, status: number): Response {
  return new Response(body, { status, headers: HTML_HEADERS });
}

export interface UnsubscribeDeps {
  /** Anything with `.from(table).update(...).eq(...)`; the tests pass a fake. */
  supabase: { from: (table: string) => unknown };
  /** The HMAC secret. Injected so a test never touches the real environment. */
  secret: string | undefined;
  crypto?: Crypto;
}

/**
 * Signs `userId` with the unsubscribe secret — the same digest
 * send-weekly-digest embeds in its links. Exported so tests can mint real
 * tokens instead of hard-coding hashes.
 */
export async function signToken(userId: string, secret: string, cryptoImpl: Crypto = crypto): Promise<string> {
  const key = await cryptoImpl.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await cryptoImpl.subtle.sign("HMAC", key, new TextEncoder().encode(userId));
  return Array.from(new Uint8Array(signature)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Compares two hex digests without leaking their common prefix length. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/** The link carries `token=user_id:hash`; only the hash is compared. */
export function extractHash(token: string): string {
  const separator = token.indexOf(":");
  return separator === -1 ? token : token.slice(separator + 1);
}

export async function handleRequest(req: Request, deps: UnsubscribeDeps): Promise<Response> {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return html(HTML_FAILED, 405);
  }

  const url = new URL(req.url);
  const userId = url.searchParams.get("user_id");
  const token = url.searchParams.get("token");

  if (!userId || !token) {
    return html(HTML_FAILED, 400);
  }

  // A missing secret used to fall back to the literal
  // "default-unsubscribe-secret", which is published in this repository: anyone
  // who read it could mint a valid unsubscribe link for any account. A missing
  // secret is a deployment fault, so it fails closed instead.
  if (!deps.secret) {
    console.error("[unsubscribe-digest] UNSUBSCRIBE_SECRET is not set; refusing to verify tokens");
    return html(HTML_FAILED, 500);
  }

  const expected = await signToken(userId, deps.secret, deps.crypto);
  if (!timingSafeEqual(extractHash(token), expected)) {
    return html(HTML_FAILED, 403);
  }

  const { error } = await (deps.supabase.from("profiles") as {
    update: (values: Record<string, unknown>) => { eq: (column: string, value: unknown) => Promise<{ error: unknown }> };
  })
    .update({ weekly_digest: false })
    .eq("id", userId);

  if (error) {
    console.error("[unsubscribe-digest] Failed to unsubscribe:", error);
    return html(HTML_FAILED, 500);
  }

  return html(HTML_SUCCESS, 200);
}
