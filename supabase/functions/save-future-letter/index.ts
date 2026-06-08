// deno-lint-ignore-file no-import-prefix
import { serve } from 'https://deno.land/std@0.192.0/http/server.ts';

type SaveFutureLetterBody = {
  userId?: string;
  content?: string;
  generatedAt?: string;
};

type SupabaseRow = {
  id: string;
  created_at: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function getEnv(name: string, fallback = '') {
  return Deno.env.get(name) ?? fallback;
}

function normalizeBase64Url(value: string) {
  const padded = value.padEnd(value.length + (4 - (value.length % 4)) % 4, '=');
  return padded.replace(/-/g, '+').replace(/_/g, '/');
}

function getAuthUserId(req: Request): string | null {
  const authHeader = req.headers.get('authorization') ?? '';
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return null;
  }

  const token = authHeader.split(' ')[1];
  const payload = token.split('.')[1];
  if (!payload) {
    return null;
  }

  try {
    const decoded = JSON.parse(
      atob(normalizeBase64Url(payload)),
    ) as Record<string, unknown>;

    return (decoded.sub ?? decoded.user_id ?? null)?.toString() ?? null;
  } catch {
    return null;
  }
}

function parseGeneratedAt(value: unknown): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return new Date().toISOString();
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('generatedAt must be a valid ISO timestamp');
  }

  return parsed.toISOString();
}

function encodeFilterValue(value: string) {
  return encodeURIComponent(value)
    .replace(/%20/g, '+')
    .replace(/%2C/g, '%2C');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const body = (await req.json()) as SaveFutureLetterBody;
    const userId = (body.userId ?? '').toString().trim();
    const content = (body.content ?? '').toString().trim();
    const generatedAt = parseGeneratedAt(body.generatedAt);

    if (!userId) {
      throw new Error('userId is required');
    }

    if (!content) {
      throw new Error('content is required');
    }

    const authUserId = getAuthUserId(req);
    if (!authUserId) {
      throw new Error('Missing authorization header');
    }

    if (authUserId !== userId) {
      throw new Error('Authenticated user does not match userId');
    }

    const supabaseUrl = getEnv('SUPABASE_URL').replace(/\/+$/, '');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
    }

    const baseUrl = `${supabaseUrl}/rest/v1/future_letters`;
    const filterQuery = `select=id,created_at&user_id=eq.${encodeFilterValue(
      userId,
    )}&content=eq.${encodeFilterValue(content)}`;

    const existingResponse = await fetch(`${baseUrl}?${filterQuery}`, {
      method: 'GET',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        Accept: 'application/json',
      },
    });

    if (!existingResponse.ok) {
      throw new Error(
        `Failed to query existing future letters: ${existingResponse.status} ${existingResponse.statusText}`,
      );
    }

    const existingData = (await existingResponse.json()) as SupabaseRow[];

    if (existingData.length > 0) {
      return jsonResponse(
        {
          id: existingData[0].id,
          existing: true,
          createdAt: existingData[0].created_at,
        },
        200,
      );
    }

    const unlockAt = new Date(
      Date.parse(generatedAt) + 30 * 24 * 60 * 60 * 1000,
    ).toISOString();

    const insertResponse = await fetch(baseUrl, {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({
        user_id: userId,
        content,
        created_at: generatedAt,
        unlock_at: unlockAt,
      }),
    });

    if (!insertResponse.ok) {
      throw new Error(
        `Failed to save future letter: ${insertResponse.status} ${insertResponse.statusText}`,
      );
    }

    const insertData = (await insertResponse.json()) as SupabaseRow[];
    if (insertData.length === 0) {
      throw new Error('Failed to persist future letter');
    }

    return jsonResponse(
      {
        id: insertData[0].id,
        createdAt: insertData[0].created_at,
      },
      201,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 400);
  }
});
