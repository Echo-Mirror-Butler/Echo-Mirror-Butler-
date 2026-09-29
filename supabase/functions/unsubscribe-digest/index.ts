/**
 * unsubscribe-digest — Supabase Edge Function
 *
 * One-click unsubscribe from weekly digest emails.
 * Called via a link in the email body (GET request).
 * Verifies an HMAC-signed token, then sets weekly_digest = false.
 *
 * Required env secret:
 *   UNSUBSCRIBE_SECRET — must match the value used by send-weekly-digest
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createLogger } from "../_shared/logger.ts";
import {
  assertUnsubscribeSecretConfigured,
  resolveUnsubscribeSecret,
  UnsubscribeSecretMissingError,
} from "../_shared/unsubscribe-hmac.ts";

const logger = createLogger("unsubscribe-digest");

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Start-up assertion (Issue #762): the request path fails closed, but a
// deployment that is missing the secret should say so in the logs at boot
// rather than only when the first user clicks an unsubscribe link.
assertUnsubscribeSecretConfigured((message) => {
  logger.error("unsubscribe_secret_not_configured", message);
});

export async function verifyToken(
  userId: string,
  tokenHash: string,
  secretOverride?: string,
): Promise<boolean> {
  // No fallback: a built-in default would be a publicly known HMAC key.
  const secret = resolveUnsubscribeSecret(Deno.env, secretOverride);
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const data = encoder.encode(userId);

  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, data);
  const expected = Array.from(new Uint8Array(signature)).map((b) =>
    b.toString(16).padStart(2, "0")
  ).join("");

  return tokenHash === expected;
}

const HTML_SUCCESS = `<!DOCTYPE html>
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

const HTML_FAILED = `<!DOCTYPE html>
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

const HTML_NOT_CONFIGURED = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Unsubscribe unavailable</title>
</head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="background:#fff;border-radius:16px;padding:40px;text-align:center;max-width:400px;margin:20px;">
<div style="font-size:48px;">⚠️</div>
<h1 style="font-size:22px;color:#1a1a2e;margin:16px 0 8px;">Unsubscribe is temporarily unavailable</h1>
<p style="color:#666;font-size:14px;margin:0;line-height:1.5;">We could not verify this link right now. Please try again later or contact support, and we will unsubscribe you manually.</p>
</div>
</body>
</html>`;

export async function unsubscribeDigestFunction(
  req: Request,
  injectedClient?: any,
): Promise<Response> {
  const url = new URL(req.url);
  const userId = url.searchParams.get("user_id");
  const token = url.searchParams.get("token");

  if (!userId || !token) {
    return new Response(HTML_FAILED, {
      status: 400,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const tokenHash = token.includes(":") ? token.split(":")[1] : token;

  let valid = false;
  try {
    valid = await verifyToken(userId, tokenHash);
  } catch (error) {
    if (error instanceof UnsubscribeSecretMissingError) {
      // Fail loudly (Issue #762): never verify with a default secret.
      logger.error("Unsubscribe link could not be verified", error.message);
      return new Response(HTML_NOT_CONFIGURED, {
        status: 500,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }
    throw error;
  }

  if (!valid) {
    return new Response(HTML_FAILED, {
      status: 403,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const supabase = injectedClient ||
    createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { error } = await supabase
    .from("profiles")
    .update({ weekly_digest: false })
    .eq("id", userId);

  if (error) {
    console.error("Failed to unsubscribe:", error);
    return new Response(HTML_FAILED, {
      status: 500,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  return new Response(HTML_SUCCESS, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

Deno.serve(unsubscribeDigestFunction);
