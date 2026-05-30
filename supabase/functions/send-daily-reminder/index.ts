/**
 * send-daily-reminder — Supabase Edge Function
 * Issue #303
 *
 * Sends Web Push notifications to all users who have:
 * - reminder_enabled = true
 * - reminder_time matching the current UTC hour (±5 min window)
 *
 * Schedule via pg_cron or Supabase scheduled functions to run every 5 minutes:
 *   SELECT cron.schedule('send-daily-reminder', '*/5 * * * *',
 *     $$SELECT net.http_post(url := '<SUPABASE_URL>/functions/v1/send-daily-reminder',
 *       headers := '{"Authorization": "Bearer <SERVICE_ROLE_KEY>"}'::jsonb)$$);
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY')!
const VAPID_PUBLIC_KEY = Deno.env.get('VAPID_PUBLIC_KEY')!
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:hello@echomirror.app'

type PushSubscription = {
  id: string
  user_id: string
  endpoint: string
  p256dh: string
  auth: string
  reminder_time: string
}

/**
 * Build a VAPID Authorization header using the Web Crypto API.
 * Implements RFC 8292 (Voluntary Application Server Identification for Web Push).
 */
async function buildVapidAuthHeader(audience: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const exp = now + 12 * 3600 // 12 hours

  const header = btoa(JSON.stringify({ typ: 'JWT', alg: 'ES256' }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const payload = btoa(JSON.stringify({ aud: audience, exp, sub: VAPID_SUBJECT }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const signingInput = `${header}.${payload}`

  // Import VAPID private key (base64url-encoded raw EC private key)
  const rawKey = Uint8Array.from(atob(VAPID_PRIVATE_KEY.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    rawKey,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const token = `${signingInput}.${sig}`
  return `vapid t=${token}, k=${VAPID_PUBLIC_KEY}`
}

async function sendPushNotification(sub: PushSubscription): Promise<boolean> {
  const url = new URL(sub.endpoint)
  const audience = `${url.protocol}//${url.host}`

  const vapidAuth = await buildVapidAuthHeader(audience)

  const payload = JSON.stringify({
    title: 'EchoMirror — Daily Check-in',
    body: "How are you feeling today? Log your mood and keep your streak alive. 🔥",
    url: '/logs/new',
  })

  const response = await fetch(sub.endpoint, {
    method: 'POST',
    headers: {
      'Authorization': vapidAuth,
      'Content-Type': 'application/json',
      'TTL': '86400',
    },
    body: payload,
  })

  return response.ok || response.status === 201
}

Deno.serve(async (req) => {
  // Allow manual POST trigger or scheduled invocation
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // Get current UTC time as HH:MM
  const now = new Date()
  const currentHour = now.getUTCHours().toString().padStart(2, '0')
  const currentMinute = now.getUTCMinutes().toString().padStart(2, '0')
  const currentTime = `${currentHour}:${currentMinute}`

  // Fetch subscriptions where reminder_time is within ±5 minutes of now
  const { data: subscriptions, error } = await supabase
    .from('push_subscriptions')
    .select('id, user_id, endpoint, p256dh, auth, reminder_time')
    .eq('reminder_enabled', true)

  if (error) {
    console.error('Failed to fetch subscriptions:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  const subs = (subscriptions ?? []) as PushSubscription[]

  // Filter to subscriptions whose reminder_time is within 5 minutes of now
  const [nowH, nowM] = currentTime.split(':').map(Number)
  const nowMinutes = nowH * 60 + nowM

  const due = subs.filter((sub) => {
    const [h, m] = sub.reminder_time.split(':').map(Number)
    const subMinutes = h * 60 + m
    return Math.abs(subMinutes - nowMinutes) <= 5
  })

  let sent = 0
  let failed = 0

  await Promise.allSettled(
    due.map(async (sub) => {
      try {
        const ok = await sendPushNotification(sub)
        if (ok) sent++
        else failed++
      } catch {
        failed++
      }
    }),
  )

  return new Response(
    JSON.stringify({ checked: due.length, sent, failed, time: currentTime }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
