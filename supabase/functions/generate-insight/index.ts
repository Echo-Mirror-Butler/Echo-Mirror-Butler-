import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseKey)

// Rate limit: 10 calls per hour for generate-insight
const MAX_CALLS_PER_HOUR = 10

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get user from JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabase.auth.getUser(token)

    if (userError || !user) {
      throw new Error('Invalid or expired token')
    }

    const userId = user.id

    // Check rate limit
    const { data: rateCheck, error: rateError } = await supabase
      .rpc('check_and_increment_rate_limit', {
        p_user_id: userId,
        p_function: 'generate-insight',
        p_max_calls: MAX_CALLS_PER_HOUR
      })

    if (rateError) {
      console.error('Rate limit check error:', rateError)
    }

    // If rate limit exceeded (returns false)
    if (rateCheck === false) {
      return new Response(
        JSON.stringify({
          error: 'Rate limit exceeded. You can only call this function 10 times per hour.',
          retryAfter: '1 hour'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 429,
        }
      )
    }

    const { recentLogs } = await req.json()
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) throw new Error('GEMINI_API_KEY is not set')

    const prompt = `Analyze these recent logs and generate a structured JSON response with prediction, suggestions, futureLetter, stressLevel, calmingMessage, musicRecommendations. Logs: ${JSON.stringify(recentLogs)}`

    // Call Gemini
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json" }
      })
    })

    if (!response.ok) {
        throw new Error(`Gemini API Error: ${response.statusText}`)
    }

    const data = await response.json()

    // Parse Gemini response
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text
    if (!aiText) throw new Error('Invalid Gemini API response')

    const resultBody = JSON.parse(aiText)

    return new Response(JSON.stringify(resultBody), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
