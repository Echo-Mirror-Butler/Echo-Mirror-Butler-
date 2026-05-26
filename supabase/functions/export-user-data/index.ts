import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

function jsonResponse(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', ...extra },
  });
}

function getEnv(name: string) {
  return Deno.env.get(name) ?? '';
}

function sanitizeCsvCell(raw: string): string {
  let s = raw;
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return s.includes(',') || s.includes('"') || s.includes('\n')
    ? `"${s.replace(/"/g, '""')}"`
    : s;
}

function toCsv(label: string, rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return `--- ${label} ---\n(no data)\n`;
  const keys = Object.keys(rows[0]);
  const header = keys.join(',');
  const body = rows.map((r) =>
    keys.map((k) => {
      const v = r[k];
      const s = typeof v === 'object' ? JSON.stringify(v) : String(v ?? '');
      return sanitizeCsvCell(s);
    }).join(',')
  ).join('\n');
  return `--- ${label} ---\n${header}\n${body}\n`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'GET') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!token) {
    return jsonResponse({ error: 'Missing authorization token' }, 401);
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server configuration error' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: authError } = await admin.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse({ error: 'Invalid or expired token' }, 401);
  }

  const lastExport = user.user_metadata?.last_export_at;
  if (lastExport) {
    const elapsed = Date.now() - new Date(lastExport).getTime();
    const oneHour = 60 * 60 * 1000;
    if (elapsed < oneHour) {
      const retryAfter = Math.ceil((oneHour - elapsed) / 1000);
      return jsonResponse(
        { error: 'Rate limited. Try again later.', retry_after_seconds: retryAfter },
        429,
        { 'Retry-After': String(retryAfter) },
      );
    }
  }

  const url = new URL(req.url);
  const format = url.searchParams.get('format') === 'csv' ? 'csv' : 'json';
  const userId = user.id;

  const [logs, gifts, insights, habits, completions] = await Promise.all([
    admin.from('log_entries').select('id, date, mood, habits, notes, created_at, updated_at').eq('user_id', userId).order('date', { ascending: false }),
    admin.from('gift_transactions').select('id, echo_amount, stellar_tx_hash, message, status, created_at').or(`sender_user_id.eq.${userId},recipient_user_id.eq.${userId}`).order('created_at', { ascending: false }),
    admin.from('ai_insights').select('id, prediction, suggestions, future_letter, stress_level, calming_message, music_recommendations, created_at').eq('user_id', userId).order('created_at', { ascending: false }),
    admin.from('habits').select('id, name, created_at').eq('user_id', userId).order('created_at', { ascending: false }),
    admin.from('habit_completions').select('id, habit_id, completed_date, created_at').eq('user_id', userId).order('completed_date', { ascending: false }),
  ]);

  const data = {
    log_entries: logs.data ?? [],
    gift_transactions: gifts.data ?? [],
    ai_insights: insights.data ?? [],
    habits: habits.data ?? [],
    habit_completions: completions.data ?? [],
  };

  await admin.auth.admin.updateUserById(userId, {
    user_metadata: { ...user.user_metadata, last_export_at: new Date().toISOString() },
  });

  const dateStr = new Date().toISOString().slice(0, 10);

  if (format === 'csv') {
    const csv = [
      toCsv('Log Entries', data.log_entries),
      toCsv('Gift Transactions', data.gift_transactions),
      toCsv('AI Insights', data.ai_insights),
      toCsv('Habits', data.habits),
      toCsv('Habit Completions', data.habit_completions),
    ].join('\n');

    return new Response(csv, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="echomirror-export-${dateStr}.csv"`,
      },
    });
  }

  return new Response(JSON.stringify(data, null, 2), {
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Disposition': `attachment; filename="echomirror-export-${dateStr}.json"`,
    },
  });
});
