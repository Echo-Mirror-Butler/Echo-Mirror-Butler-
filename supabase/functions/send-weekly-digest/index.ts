/**
 * send-weekly-digest — Supabase Edge Function
 *
 * Sends a "Your week in review" email to all users who have weekly_digest = true.
 * Called via pg_cron every Sunday at 09:00 UTC (see migration).
 *
 * Required env secrets (set via `supabase secrets set`):
 *   RESEND_API_KEY        — Resend API key for email sending
 *   UNSUBSCRIBE_SECRET    — secret used to sign unsubscribe tokens
 *   APP_URL               — frontend URL for CTA links (default: https://echomirrorbutler.vercel.app)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const UNSUBSCRIBE_SECRET = Deno.env.get('UNSUBSCRIBE_SECRET') ?? 'default-unsubscribe-secret'
const APP_URL = Deno.env.get('APP_URL') ?? 'https://echomirrorbutler.vercel.app'

type LogEntry = {
  date: string
  mood: number | null
  habits: string[]
  notes: string | null
}

type WeeklyStats = {
  avgMood: number | null
  daysLogged: number
  topHabits: string[]
  streak: number
  echoEarned: number
}

function calculateStats(logs: LogEntry[]): Omit<WeeklyStats, 'streak' | 'echoEarned'> {
  const moods = logs.filter((l) => l.mood != null).map((l) => l.mood!)
  const avgMood =
    moods.length > 0
      ? Math.round((moods.reduce((a, b) => a + b, 0) / moods.length) * 10) / 10
      : null

  const habitCounts = new Map<string, number>()
  for (const log of logs) {
    for (const habit of log.habits ?? []) {
      habitCounts.set(habit, (habitCounts.get(habit) ?? 0) + 1)
    }
  }

  const topHabits = [...habitCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([name]) => name)

  return { avgMood, daysLogged: logs.length, topHabits }
}

function getMoodEmoji(mood: number): string {
  return { 1: '😢', 2: '😕', 3: '😐', 4: '🙂', 5: '😄' }[mood] ?? '😐'
}

function getMoodLabel(mood: number): string {
  return { 1: 'Tough', 2: 'Down', 3: 'Okay', 4: 'Good', 5: 'Great' }[mood] ?? 'Okay'
}

function truncate(str: string, max: number): string {
  return str.length > max ? str.slice(0, max).replace(/\s+\S*$/, '') + '…' : str
}

async function createUnsubscribeToken(userId: string): Promise<string> {
  const encoder = new TextEncoder()
  const keyData = encoder.encode(UNSUBSCRIBE_SECRET)
  const data = encoder.encode(userId)

  const key = await crypto.subtle.importKey('raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const signature = await crypto.subtle.sign('HMAC', key, data)
  const hash = Array.from(new Uint8Array(signature)).map((b) => b.toString(16).padStart(2, '0')).join('')

  return `${userId}:${hash}`
}

function buildEmailHtml(
  stats: WeeklyStats,
  displayName: string | null,
  quote: string | null,
  unsubscribeUrl: string,
): string {
  const name = displayName?.trim() || 'EchoMirror user'
  const emoji = stats.avgMood ? getMoodEmoji(Math.round(stats.avgMood)) : '—'
  const label = stats.avgMood ? getMoodLabel(Math.round(stats.avgMood)) : 'N/A'

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:20px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;">
<tr><td style="background:linear-gradient(135deg,#6366F1,#8B5CF6);padding:32px;text-align:center;">
<h1 style="color:#fff;font-size:24px;margin:0;font-weight:700;">Your EchoMirror Week</h1>
<p style="color:rgba(255,255,255,0.85);font-size:14px;margin:8px 0 0;">Hey ${name}, here's your weekly recap</p>
</td></tr>
<tr><td style="padding:32px 32px 0;">
<h2 style="color:#1a1a2e;font-size:18px;margin:0 0 16px;">Week at a Glance</h2>
<table width="100%" cellpadding="0" cellspacing="0">
<tr>
<td width="50%" style="padding:8px;">
<div style="background:#f0f0ff;border-radius:12px;padding:16px;text-align:center;">
<div style="font-size:32px;">${emoji}</div>
<div style="font-size:24px;font-weight:700;color:#6366F1;margin:4px 0;">${stats.avgMood ?? '—'}</div>
<div style="font-size:12px;color:#666;">Avg Mood (${label})</div>
</div>
</td>
<td width="50%" style="padding:8px;">
<div style="background:#f0fdf4;border-radius:12px;padding:16px;text-align:center;">
<div style="font-size:32px;">📅</div>
<div style="font-size:24px;font-weight:700;color:#10B981;margin:4px 0;">${stats.daysLogged}</div>
<div style="font-size:12px;color:#666;">Days Logged</div>
</div>
</td>
</tr>
<tr>
<td width="50%" style="padding:8px;">
<div style="background:#fff7ed;border-radius:12px;padding:16px;text-align:center;">
<div style="font-size:32px;">🔥</div>
<div style="font-size:24px;font-weight:700;color:#f97316;margin:4px 0;">${stats.streak}</div>
<div style="font-size:12px;color:#666;">Day Streak</div>
</div>
</td>
<td width="50%" style="padding:8px;">
<div style="background:#fdf2f8;border-radius:12px;padding:16px;text-align:center;">
<div style="font-size:32px;">🪙</div>
<div style="font-size:24px;font-weight:700;color:#EC4899;margin:4px 0;">${stats.echoEarned}</div>
<div style="font-size:12px;color:#666;">ECHO Earned</div>
</div>
</td>
</tr>
</table>
</td></tr>
${stats.topHabits.length > 0 ? `
<tr><td style="padding:24px 32px 0;">
<h2 style="color:#1a1a2e;font-size:18px;margin:0 0 12px;">Top Habits</h2>
${stats.topHabits.map((h, i) => `<div style="display:inline-block;background:#e0e7ff;color:#4338ca;padding:8px 16px;border-radius:20px;font-size:14px;margin:0 6px 6px 0;">${['🥇','🥈','🥉'][i]||'•'} ${h}</div>`).join('')}
</td></tr>` : ''}
${quote ? `
<tr><td style="padding:24px 32px 0;">
<div style="background:linear-gradient(135deg,#f0f0ff,#fdf2f8);border-radius:12px;padding:20px;border-left:4px solid #8B5CF6;">
<p style="font-style:italic;color:#4a4a6a;font-size:14px;margin:0;line-height:1.5;">"${truncate(quote, 280)}"</p>
<p style="color:#8B5CF6;font-size:12px;margin:8px 0 0;font-weight:600;">💡 Your AI Insight</p>
</div>
</td></tr>` : ''}
<tr><td style="padding:32px;text-align:center;">
<a href="${APP_URL}" style="display:inline-block;background:linear-gradient(135deg,#6366F1,#8B5CF6);color:#fff;text-decoration:none;padding:14px 32px;border-radius:12px;font-size:16px;font-weight:600;">View your insights →</a>
</td></tr>
<tr><td style="padding:0 32px 24px;text-align:center;">
<a href="${unsubscribeUrl}" style="color:#999;font-size:11px;text-decoration:underline;">Unsubscribe from weekly digest</a>
</td></tr>
<tr><td style="background:#fafafa;padding:16px 32px;text-align:center;border-top:1px solid #eee;">
<p style="color:#999;font-size:11px;margin:0;">EchoMirror Butler — Wellness is better together</p>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  const { data: profiles, error: profileError } = await supabase
    .from('profiles')
    .select('id, display_name')
    .eq('weekly_digest', true)

  if (profileError) {
    console.error('Failed to fetch opted-in profiles:', profileError)
    return new Response(JSON.stringify({ error: profileError.message }), { status: 500 })
  }

  if (!profiles || profiles.length === 0) {
    return new Response(JSON.stringify({ sent: 0, message: 'No users opted in' }))
  }

  const sevenDaysAgo = new Date()
  sevenDaysAgo.setUTCDate(sevenDaysAgo.getUTCDate() - 7)
  const since = sevenDaysAgo.toISOString()

  let sent = 0
  let failed = 0

  await Promise.allSettled(
    profiles.map(async (profile) => {
      try {
        const { data: userData, error: userError } = await supabase.auth.admin.getUserById(
          profile.id,
        )
        if (userError || !userData?.user?.email) {
          console.error(`No email for user ${profile.id}: ${userError?.message ?? 'unknown'}`)
          failed++
          return
        }
        const email = userData.user.email!

        const { data: logs } = await supabase
          .from('log_entries')
          .select('date, mood, habits, notes')
          .eq('user_id', profile.id)
          .gte('date', since)
          .order('date', { ascending: false })

        const logEntries = (logs ?? []) as LogEntry[]

        const { data: profileRow } = await supabase
          .from('profiles')
          .select('streak')
          .eq('id', profile.id)
          .maybeSingle()

        const { data: rewards } = await supabase
          .from('echo_rewards')
          .select('amount')
          .eq('user_id', profile.id)
          .gte('created_at', since)

        const echoEarned = (rewards ?? []).reduce((sum: number, r: { amount: number }) => sum + (r.amount ?? 0), 0)

        const base = calculateStats(logEntries)
        const stats: WeeklyStats = {
          ...base,
          streak: (profileRow as { streak?: number } | null)?.streak ?? 0,
          echoEarned,
        }

        const { data: insights } = await supabase
          .from('ai_insights')
          .select('prediction')
          .eq('user_id', profile.id)
          .order('created_at', { ascending: false })
          .limit(1)

        const quote = (insights && insights.length > 0)
          ? (insights[0] as { prediction: string }).prediction
          : null

        const token = await createUnsubscribeToken(profile.id)
        const unsubscribeUrl = `${SUPABASE_URL}/functions/v1/unsubscribe-digest?user_id=${profile.id}&token=${encodeURIComponent(token)}`

        const html = buildEmailHtml(stats, profile.display_name, quote, unsubscribeUrl)

        const moodEmoji = stats.avgMood ? getMoodEmoji(Math.round(stats.avgMood)) : '📊'
        const subject = stats.daysLogged > 0
          ? `Your EchoMirror week: ${moodEmoji} ${stats.avgMood} avg mood, ${stats.streak}🔥 streak`
          : `Your EchoMirror week: No entries this week`

        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: 'EchoMirror Butler <digest@echomirrorbutler.vercel.app>',
            to: [email],
            subject,
            html,
          }),
        })

        if (res.ok) {
          sent++
        } else {
          const body = await res.text()
          console.error(`Resend error for ${profile.id}:`, res.status, body)
          failed++
        }
      } catch (err) {
        console.error(`Failed for user ${profile.id}:`, err)
        failed++
      }
    }),
  )

  return new Response(
    JSON.stringify({ sent, failed, total: profiles.length }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
