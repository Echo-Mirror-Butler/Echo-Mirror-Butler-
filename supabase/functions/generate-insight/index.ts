import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        },
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify user and get user ID
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const userId = user.id;

    // Check minimum log requirement (at least 3 logs)
    const { count: logCount } = await supabase
      .from("mood_logs")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId);

    if ((logCount ?? 0) < 3) {
      return new Response(
        JSON.stringify({ error: "Need at least 3 logs to generate insight" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 422,
        },
      );
    }

    // Check rate limit: 1 insight per 24 hours
    const twentyFourHoursAgo = new Date(
      Date.now() - 24 * 60 * 60 * 1000,
    ).toISOString();
    const { count: insightCount } = await supabase
      .from("ai_insights")
      .select("*", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", twentyFourHoursAgo);

    if ((insightCount ?? 0) >= 1) {
      // Get the most recent insight to calculate retry time
      const { data: recentInsight } = await supabase
        .from("ai_insights")
        .select("created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      const retryAfterSeconds = recentInsight
        ? Math.ceil(
            (new Date(recentInsight.created_at).getTime() +
              24 * 60 * 60 * 1000 -
              Date.now()) /
              1000,
          )
        : 86400; // Default 24 hours

      return new Response(
        JSON.stringify({
          error: "Rate limit: 1 insight per 24 hours",
          retryAfter: retryAfterSeconds,
        }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": retryAfterSeconds.toString(),
          },
          status: 429,
        },
      );
    }

    const { recentLogs, previousFollowThroughRate } = await req.json();
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

    let prompt = `Analyze these recent logs and generate a structured JSON response with:
- prediction: concise paragraph
- suggestions: string[]
- futureLetter: string
- stressLevel: number from 0 to 5
- calmingMessage: string
- musicRecommendations: string[]
- moodDrivers: array of { label: string, percentage: number } where percentages total around 100
- bestTimeOfDay: one of Morning, Afternoon, Evening, Night
- worstTimeOfDay: one of Morning, Afternoon, Evening, Night
- recommendations: actionable recommendation strings
- moodScore: integer from 1 to 5 representing overall mood of user

Logs: ${JSON.stringify(recentLogs)}`;

    if (previousFollowThroughRate) {
      prompt += `\n\nNote: In the previous cycle, the user followed ${previousFollowThroughRate.acted} out of ${previousFollowThroughRate.total} recommendations. Please adjust your recommendations to be more achievable, encouraging, or tailored based on this follow-through rate.`;
    }

    // Call Gemini
    const response = await fetch(
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

    if (!response.ok) {
      throw new Error(`Gemini API Error: ${response.statusText}`);
    }

    const data = await response.json();

    // Parse Gemini response
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!aiText) throw new Error("Invalid Gemini API response");

    const resultBody = JSON.parse(aiText);

    return new Response(JSON.stringify(resultBody), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
