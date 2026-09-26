import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Request handler for `generate-insight`, separated from `index.ts` so it can be
 * called without starting a server: `index.ts` only wires it to `serve()`, while
 * the tests import this module with injected dependencies and never touch
 * Supabase, Gemini or the network (issue #735).
 */

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000;
export const MIN_LOGS_REQUIRED = 3;

export interface GenerateInsightDeps {
  /** Anything with Supabase's `.auth.getUser()` and `.from(table)...` chain. */
  supabase: ReturnType<typeof createClient>;
  fetch: typeof fetch;
  /** Reads configuration; the default reads Deno.env, tests pass a stub. */
  env?: (name: string) => string | undefined;
  /** Milliseconds since epoch; defaults to Date.now(), tests pass a fixed clock. */
  now?: () => number;
}

export function createSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

function respond(body: unknown, status: number, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS, ...extraHeaders },
  });
}

class HttpError extends Error {
  status: number;
  body: Record<string, unknown>;
  constructor(status: number, body: Record<string, unknown>) {
    super(String(body.error ?? "error"));
    this.status = status;
    this.body = body;
  }
}

export async function handleRequest(req: Request, deps: GenerateInsightDeps): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Method check: anything but POST is a client error, not an auth error.
    if (req.method !== "POST") {
      return respond({ error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, 405);
    }

    const env = deps.env ?? ((name: string) => Deno.env.get(name));
    const now = deps.now ?? (() => Date.now());

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return respond({ error: "Missing authorization header", code: "UNAUTHORIZED" }, 401);
    }

    // Verify user and get user ID
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await deps.supabase.auth.getUser(token);

    if (authError || !user) {
      return respond({ error: "Unauthorized", code: "UNAUTHORIZED" }, 401);
    }

    const userId = user.id;

    // Check minimum log requirement (at least 3 logs)
    const { count: logCount } = await deps.supabase
      .from("mood_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId);

    if ((logCount ?? 0) < MIN_LOGS_REQUIRED) {
      return respond(
        { error: "Need at least 3 logs to generate insight", code: "INSUFFICIENT_LOGS" },
        422,
      );
    }

    // Check rate limit: 1 insight per 24 hours
    const twentyFourHoursAgo = new Date(now() - RATE_LIMIT_WINDOW_MS).toISOString();
    const { count: insightCount } = await deps.supabase
      .from("ai_insights")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", twentyFourHoursAgo);

    if ((insightCount ?? 0) >= 1) {
      // Get the most recent insight to calculate retry time
      const { data: recentInsight } = await deps.supabase
        .from("ai_insights")
        .select("created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      const retryAfterSeconds = recentInsight
        ? Math.ceil(
            (new Date(recentInsight.created_at).getTime() +
              RATE_LIMIT_WINDOW_MS -
              now()) /
              1000,
          )
        : 86400; // Default 24 hours

      return respond(
        {
          error: "Rate limit: 1 insight per 24 hours",
          retryAfter: retryAfterSeconds,
          code: "RATE_LIMITED",
        },
        429,
        { "Retry-After": retryAfterSeconds.toString() },
      );
    }

    // A malformed body is a client error and is answered as one, before any
    // upstream call is made.
    let reqBody: Record<string, unknown>;
    try {
      reqBody = await req.json();
    } catch {
      return respond({ error: "Invalid JSON body", code: "INVALID_BODY" }, 400);
    }

    const {
      privacyMode,
      recentLogs,
      sanitizedLogs,
      moodTrend,
      habitFrequencies,
      habitMoodCorrelations,
      temporalPatterns,
      clusters,
      similarityHighlights,
      previousFollowThroughRate,
    } = reqBody;

    const apiKey = env("GEMINI_API_KEY");
    if (!apiKey) {
      // A missing key is a server configuration problem, never a 400.
      throw new HttpError(500, { error: "GEMINI_API_KEY is not set", code: "CONFIG_ERROR" });
    }

    let prompt = "";

    if (privacyMode || sanitizedLogs || moodTrend) {
      // Privacy-preserving prompt construction: derived metrics + on-device clusters
      prompt = `Analyze these privacy-preserving user behavioral metrics, mood trajectories, and on-device embedding clusters (reflection notes were embedded locally and strictly kept on-device; no raw text is provided) to generate a deeply personalized and empathetic structured JSON insight response:

1. Mood Metrics & Trajectory:
- Average Mood: ${moodTrend?.average ?? "N/A"}/5 (Range: ${moodTrend?.min ?? "N/A"} to ${moodTrend?.max ?? "N/A"})
- Trend Direction: ${moodTrend?.direction ?? "stable"} (Linear Slope: ${moodTrend?.slope ?? 0}, Volatility: ${moodTrend?.volatility ?? 0})

2. Habit & Behavior Statistics:
- Habit Completion Counts: ${JSON.stringify(habitFrequencies ?? {})}
- Habit Mood Correlations (Avg mood when performed): ${JSON.stringify(habitMoodCorrelations ?? {})}

3. Temporal Dynamics:
- Peak Active / Positive Time: ${temporalPatterns?.bestTimeOfDay ?? "Morning"}
- Challenging / Low Energy Time: ${temporalPatterns?.worstTimeOfDay ?? "Night"}
- Day of Week Averages: ${JSON.stringify(temporalPatterns?.weekdayAverages ?? {})}

4. On-Device Semantic Clusters & Similarity Recurrences:
- Behavioral & Theme Clusters: ${JSON.stringify(clusters ?? [])}
- Similarity Pattern Matches: ${JSON.stringify(similarityHighlights ?? [])}

5. Chronological Log History:
${JSON.stringify(sanitizedLogs ?? [])}

Generate a structured JSON response with:
- prediction: concise paragraph (at least 200 characters) forecasting next month's trajectory referencing patterns, habits, and mood trends
- suggestions: string[] (at least 30 characters each) with context-aware, actionable suggestions
- futureLetter: an encouraging letter (at least 300 characters) from their future self referencing specific dates, habits, and milestones
- stressLevel: number from 0 to 5 based on mood volatility and trend decline
- calmingMessage: soothing message
- musicRecommendations: string[]
- moodDrivers: array of { label: string, percentage: number } where percentages total around 100
- bestTimeOfDay: one of Morning, Afternoon, Evening, Night
- worstTimeOfDay: one of Morning, Afternoon, Evening, Night
- recommendations: actionable recommendation strings
- moodScore: integer from 1 to 5 representing overall mood of user`;
    } else {
      // Legacy plaintext logs prompt
      prompt = `Analyze these recent logs and generate a structured JSON response with:
- prediction: concise paragraph (at least 200 characters)
- suggestions: string[]
- futureLetter: string (at least 300 characters)
- stressLevel: number from 0 to 5
- calmingMessage: string
- musicRecommendations: string[]
- moodDrivers: array of { label: string, percentage: number } where percentages total around 100
- bestTimeOfDay: one of Morning, Afternoon, Evening, Night
- worstTimeOfDay: one of Morning, Afternoon, Evening, Night
- recommendations: actionable recommendation strings
- moodScore: integer from 1 to 5 representing overall mood of user

Logs: ${JSON.stringify(recentLogs ?? [])}`;
    }

    if (previousFollowThroughRate) {
      prompt += `\n\nNote: In the previous cycle, the user followed ${previousFollowThroughRate.acted} out of ${previousFollowThroughRate.total} recommendations. Please adjust your recommendations to be more achievable, encouraging, or tailored based on this follow-through rate.`;
    }

    // Call Gemini
    let response: Response;
    try {
      response = await deps.fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema: {
                type: "OBJECT",
                properties: {
                  prediction: { type: "STRING" },
                  suggestions: { type: "ARRAY", items: { type: "STRING" } },
                  futureLetter: { type: "STRING" },
                  stressLevel: { type: "INTEGER" },
                  calmingMessage: { type: "STRING" },
                  musicRecommendations: {
                    type: "ARRAY",
                    items: { type: "STRING" },
                  },
                  moodDrivers: {
                    type: "ARRAY",
                    items: {
                      type: "OBJECT",
                      properties: {
                        label: { type: "STRING" },
                        percentage: { type: "INTEGER" },
                      },
                      required: ["label", "percentage"],
                    },
                  },
                  bestTimeOfDay: { type: "STRING" },
                  worstTimeOfDay: { type: "STRING" },
                  recommendations: { type: "ARRAY", items: { type: "STRING" } },
                  moodScore: { type: "INTEGER" },
                },
                required: [
                  "prediction",
                  "suggestions",
                  "futureLetter",
                  "stressLevel",
                  "moodDrivers",
                  "bestTimeOfDay",
                  "worstTimeOfDay",
                  "recommendations",
                  "moodScore",
                ],
              },
            },
          }),
        },
      );
    } catch (fetchError) {
      // A network failure to the AI provider is an upstream error (502), not a
      // client mistake.
      const message = fetchError instanceof Error ? fetchError.message : String(fetchError);
      console.error("[generate-insight] Gemini request failed:", message);
      throw new HttpError(502, { error: "AI provider request failed", details: message, code: "UPSTREAM_ERROR" });
    }

    if (!response.ok) {
      console.error("[generate-insight] Gemini API error:", response.status, response.statusText);
      throw new HttpError(
        502,
        { error: "AI provider request failed", details: `Gemini API Error: ${response.statusText}`, code: "UPSTREAM_ERROR" },
      );
    }

    let data: { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
    try {
      data = await response.json();
    } catch {
      throw new HttpError(502, { error: "AI provider request failed", details: "Invalid Gemini API response", code: "UPSTREAM_ERROR" });
    }

    // Parse Gemini response
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!aiText) {
      throw new HttpError(502, { error: "AI provider request failed", details: "Invalid Gemini API response", code: "UPSTREAM_ERROR" });
    }

    let resultBody: unknown;
    try {
      resultBody = JSON.parse(aiText);
    } catch {
      throw new HttpError(502, { error: "AI provider request failed", details: "AI response is not valid JSON", code: "UPSTREAM_ERROR" });
    }

    return respond(resultBody, 200);
  } catch (error) {
    if (error instanceof HttpError) {
      return respond(error.body, error.status);
    }
    const message = error instanceof Error ? error.message : String(error);
    console.error("[generate-insight] Unexpected error:", message);
    // Anything that is not a validated upstream/client failure is a server
    // error, not a 400.
    return respond({ error: "Internal server error", details: message, code: "INTERNAL_ERROR" }, 500);
  }
}
