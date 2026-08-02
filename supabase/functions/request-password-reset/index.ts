/**
 * Issue #633: Password reset with server-side rate limiting.
 *
 * Always returns a generic success payload so callers cannot enumerate
 * whether an email is registered. Rate-limits by email hash and client IP.
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: jsonHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server misconfigured' }, 500)
  }

  let body: { email?: string; redirectTo?: string }
  try {
    body = await req.json()
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const email = (body.email ?? '').trim().toLowerCase()
  if (!email || !isValidEmail(email)) {
    // Generic response — do not reveal validation details that aid probing
    return jsonResponse(GENERIC_SUCCESS)
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const emailKey = `email:${await sha256Hex(email)}`
  const ipKey = `ip:${clientIp(req)}`

  // 3 resets per email / hour
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
    // Fail closed for abuse protection while still not leaking existence
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

  const origin = req.headers.get('origin') ?? ''
  const redirectTo =
    typeof body.redirectTo === 'string' && body.redirectTo.startsWith('http')
      ? body.redirectTo
      : origin
        ? `${origin}/update-password`
        : undefined

  // Fire reset; ignore "user not found" style errors for anti-enumeration
  try {
    const { error } = await admin.auth.resetPasswordForEmail(email, {
      redirectTo,
    })
    if (error) {
      console.error('resetPasswordForEmail error', error.message)
    }
  } catch (err) {
    console.error('resetPasswordForEmail threw', err)
  }

  return jsonResponse(GENERIC_SUCCESS)
})
