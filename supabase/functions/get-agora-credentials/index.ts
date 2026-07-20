import { serve } from "https://deno.land/std@0.192.0/http/server.ts"
import { RtcTokenBuilder, RtcRole } from "npm:agora-access-token@2.0.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { sessionId, userId } = await req.json()
    
    const appId = Deno.env.get('AGORA_APP_ID')
    const appCert = Deno.env.get('AGORA_APP_CERT')

    if (!appId || !appCert) {
      throw new Error('Agora credentials not configured')
    }
    if (!sessionId || !userId) {
      throw new Error('sessionId and userId are required')
    }

    const role = RtcRole.PUBLISHER
    const expirationTimeInSeconds = 3600 * 24
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

    const token = RtcTokenBuilder.buildTokenWithAccount(
      appId, 
      appCert, 
      sessionId, 
      userId, 
      role, 
      privilegeExpiredTs
    )

    return new Response(JSON.stringify({ token, appId }), {
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
