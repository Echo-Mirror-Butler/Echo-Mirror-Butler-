/**
 * Request handler for `save-future-letter`, separated from `index.ts` so it
 * can be called without starting a server. Supabase REST access (fetch), the
 * environment and the clock arrive through `deps`, so the offline tests import
 * this module with fakes and never touch Supabase (issue #735). The runtime
 * wiring lives in `index.ts`.
 */

type SaveFutureLetterBody = {
  userId?: string;
  content?: string;
  generatedAt?: string;
};

type SupabaseRow = {
  id: string;
  created_at: string;
};

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

export interface SaveFutureLetterDeps {
  fetch: typeof fetch;
  /** Reads configuration; the tests supply an in-memory map. */
  env: (name: string) => string | undefined;
  /** Clock, injectable so `generatedAt` defaults are deterministic. */
  now?: () => Date;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
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

function parseGeneratedAt(value: unknown, now: () => Date): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return now().toISOString();
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

export async function handleRequest(
  req: Request,
  deps: SaveFutureLetterDeps,
): Promise<Response> {
  const getEnv = (name: string): string => deps.env(name) ?? '';
  const now = deps.now ?? (() => new Date());

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed', code: 'METHOD_NOT_ALLOWED' }, 405);
  }

  try {
    let body: SaveFutureLetterBody;
    try {
      body = (await req.json()) as SaveFutureLetterBody;
    } catch {
      return jsonResponse({ error: 'Invalid JSON body', code: 'INVALID_BODY' }, 400);
    }

    const userId = (body.userId ?? '').toString().trim();
    const content = (body.content ?? '').toString().trim();

    if (!userId) {
      return jsonResponse({ error: 'userId is required', code: 'MISSING_FIELD' }, 400);
    }

    if (!content) {
      return jsonResponse({ error: 'content is required', code: 'MISSING_FIELD' }, 400);
    }

    let generatedAt: string;
    try {
      generatedAt = parseGeneratedAt(body.generatedAt, now);
    } catch {
      return jsonResponse({
        error: 'generatedAt must be a valid ISO timestamp',
        code: 'INVALID_GENERATED_AT',
      }, 400);
    }

    const authUserId = getAuthUserId(req);
    if (!authUserId) {
      return jsonResponse({ error: 'Missing authorization header', code: 'UNAUTHORIZED' }, 401);
    }

    if (authUserId !== userId) {
      return jsonResponse(
        { error: 'Authenticated user does not match userId', code: 'USER_MISMATCH' },
        401,
      );
    }

    const supabaseUrl = getEnv('SUPABASE_URL').replace(/\/+$/, '');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required',
        code: 'CONFIG_ERROR',
      }, 500);
    }

    const baseUrl = `${supabaseUrl}/rest/v1/future_letters`;
    const filterQuery = `select=id,created_at&user_id=eq.${encodeFilterValue(
      userId,
    )}&content=eq.${encodeFilterValue(content)}`;

    // Supabase is an external service: a failed query/insert is an upstream
    // problem and maps to 502, not to a client 400.
    let existingResponse: Response;
    try {
      existingResponse = await deps.fetch(`${baseUrl}?${filterQuery}`, {
        method: 'GET',
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
          Accept: 'application/json',
        },
      });
    } catch (fetchError) {
      const message = fetchError instanceof Error ? fetchError.message : String(fetchError);
      console.error('[save-future-letter] Existing-letter query failed:', message);
      return jsonResponse({ error: `Failed to query existing future letters: ${message}`, code: 'UPSTREAM_ERROR' }, 502);
    }

    if (!existingResponse.ok) {
      return jsonResponse({
        error: `Failed to query existing future letters: ${existingResponse.status} ${existingResponse.statusText}`,
        code: 'UPSTREAM_ERROR',
      }, 502);
    }

    let existingData: SupabaseRow[];
    try {
      existingData = (await existingResponse.json()) as SupabaseRow[];
    } catch {
      return jsonResponse({
        error: 'Existing-letter query returned an invalid body',
        code: 'UPSTREAM_ERROR',
      }, 502);
    }

    if (Array.isArray(existingData) && existingData.length > 0) {
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

    let insertResponse: Response;
    try {
      insertResponse = await deps.fetch(baseUrl, {
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
    } catch (fetchError) {
      const message = fetchError instanceof Error ? fetchError.message : String(fetchError);
      console.error('[save-future-letter] Insert failed:', message);
      return jsonResponse({ error: `Failed to save future letter: ${message}`, code: 'UPSTREAM_ERROR' }, 502);
    }

    if (!insertResponse.ok) {
      return jsonResponse({
        error: `Failed to save future letter: ${insertResponse.status} ${insertResponse.statusText}`,
        code: 'UPSTREAM_ERROR',
      }, 502);
    }

    let insertData: SupabaseRow[];
    try {
      insertData = (await insertResponse.json()) as SupabaseRow[];
    } catch {
      return jsonResponse({
        error: 'Insert returned an invalid body',
        code: 'UPSTREAM_ERROR',
      }, 502);
    }

    if (!Array.isArray(insertData) || insertData.length === 0) {
      return jsonResponse({
        error: 'Failed to persist future letter',
        code: 'UPSTREAM_ERROR',
      }, 502);
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
    console.error('[save-future-letter] Error:', message);
    return jsonResponse({ error: message, code: 'INTERNAL_ERROR' }, 500);
  }
}
