import { serve } from "https://deno.land/std@0.192.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
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
