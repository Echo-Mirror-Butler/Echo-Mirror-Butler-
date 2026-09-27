/**
 * Issue #633 & Issue #743: Password reset with authorization and rate limiting.
 *
 * Security (Issue #743):
 * Verifies caller Authorization Bearer token to prevent unauthenticated email abuse
 * and mail bombing against arbitrary third-party addresses.
 * Sends reset only for the authenticated caller's verified account.
 */

import { createClient } from 'npm:@supabase/supabase-js@2'

const jsonHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

const GENERIC_SUCCESS = {
  success: true,
  message:
    'If an account exists for that email, a password reset link has been sent.',
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

function clientIp(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for')
  if (forwarded) {
    return forwarded.split(',')[0]?.trim() || 'unknown'
  }
  return (
    req.headers.get('cf-connecting-ip') ||
    req.headers.get('x-real-ip') ||
    'unknown'
  )
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

export async function requestPasswordResetFunction(req: Request, injectedClient?: any): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: jsonHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  // 1. Verify Authorization Header (Issue #743)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return jsonResponse(
      { error: 'Unauthorized', message: 'Authentication required to request password reset' },
      401,
    )
  }

  let admin = injectedClient
  if (!admin) {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'Server misconfigured' }, 500)
    }

    admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
  }

  // 2. Validate Session with Supabase Auth
  const token = authHeader.slice(7)
  const { data: userData, error: authError } = await admin.auth.getUser(token)

  if (authError || !userData?.user) {
    return jsonResponse(
      { error: 'Unauthorized', message: 'Invalid or expired session' },
      401,
    )
  }

  const authenticatedEmail = (userData.user.email ?? '').trim().toLowerCase()
  if (!authenticatedEmail) {
    return jsonResponse({ error: 'User account has no associated email' }, 400)
  }

  let body: { email?: string; redirectTo?: string } = {}
  try {
    body = await req.json()
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const requestedEmail = (body.email ?? '').trim().toLowerCase()

  // Caller can omit email (defaults to session email) or must match their own email
  if (requestedEmail && requestedEmail !== authenticatedEmail) {
    return jsonResponse(
      {
        error: 'Forbidden',
        message: 'Cannot request password reset for an email address other than your own',
      },
      403,
    )
  }

  const targetEmail = authenticatedEmail

  if (!isValidEmail(targetEmail)) {
    return jsonResponse(GENERIC_SUCCESS)
  }

  const emailKey = `email:${await sha256Hex(targetEmail)}`
  const ipKey = `ip:${clientIp(req)}`

  // 3 resets per email / hour
  if (typeof admin.rpc === 'function') {
    const { data: emailAllowed, error: emailLimitErr } = await admin.rpc(
      'check_auth_rate_limit',
      {
        p_key: emailKey,
        p_action: 'password_reset',
        p_max_count: 3,
        p_window_minutes: 60,
      },
    )

    if (emailLimitErr) {
      console.error('check_auth_rate_limit email error', emailLimitErr)
      return jsonResponse(
        {
          error: 'rate_limit_exceeded',
          message: 'Too many reset attempts. Please try again later.',
          retry_after_seconds: 3600,
        },
        429,
      )
    }

    if (emailAllowed === false) {
      return jsonResponse(
        {
          error: 'rate_limit_exceeded',
          message: 'Too many reset attempts. Please try again later.',
          retry_after_seconds: 3600,
        },
        429,
      )
    }

    // 10 resets per IP / hour
    const { data: ipAllowed, error: ipLimitErr } = await admin.rpc(
      'check_auth_rate_limit',
      {
        p_key: ipKey,
        p_action: 'password_reset',
        p_max_count: 10,
        p_window_minutes: 60,
      },
    )

    if (ipLimitErr) {
      console.error('check_auth_rate_limit ip error', ipLimitErr)
    }

    if (ipAllowed === false) {
      return jsonResponse(
        {
          error: 'rate_limit_exceeded',
          message: 'Too many reset attempts. Please try again later.',
          retry_after_seconds: 3600,
        },
        429,
      )
    }
  }

  const origin = req.headers.get('origin') ?? ''
  const redirectTo =
    typeof body.redirectTo === 'string' && body.redirectTo.startsWith('http')
      ? body.redirectTo
      : origin
        ? `${origin}/update-password`
        : undefined

  // Fire reset
  try {
    const { error } = await admin.auth.resetPasswordForEmail(targetEmail, {
      redirectTo,
    })
    if (error) {
      console.error('resetPasswordForEmail error', error.message)
    }
  } catch (err) {
    console.error('resetPasswordForEmail threw', err)
  }

  return jsonResponse(GENERIC_SUCCESS)
}

Deno.serve(requestPasswordResetFunction)
