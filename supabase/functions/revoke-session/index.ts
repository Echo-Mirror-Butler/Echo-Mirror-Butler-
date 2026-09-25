import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors_headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RevokeSessionRequest {
  session_id: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors_headers });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...cors_headers, "Content-Type": "application/json" },
        }
      );
    }

    const { session_id } = (await req.json()) as RevokeSessionRequest;

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "session_id is required" }),
        {
          status: 400,
          headers: { ...cors_headers, "Content-Type": "application/json" },
        }
      );
    }

    const { data: session, error: fetchError } = await supabaseClient
      .from("user_sessions")
      .select("user_id, refresh_token_id")
      .eq("id", session_id)
      .eq("user_id", user.id)
      .single();

    if (fetchError || !session) {
      return new Response(
        JSON.stringify({ error: "Session not found or access denied" }),
        {
          status: 404,
          headers: { ...cors_headers, "Content-Type": "application/json" },
        }
      );
    }

    if (!session.refresh_token_id) {
      return new Response(
        JSON.stringify({
          error: "Session does not have a linked refresh token",
        }),
        {
          status: 400,
          headers: { ...cors_headers, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    const { error: revokeError } = await supabaseAdmin.auth.admin.signOut(
      session.refresh_token_id
    );

    if (revokeError) {
      console.error("[revoke-session] Failed to revoke token:", revokeError);
      return new Response(
        JSON.stringify({
          error: "Failed to revoke session",
          details: revokeError.message,
        }),
        {
          status: 500,
          headers: { ...cors_headers, "Content-Type": "application/json" },
        }
      );
    }

    await supabaseClient
      .from("user_sessions")
      .delete()
      .eq("id", session_id)
      .eq("user_id", user.id);

    return new Response(
      JSON.stringify({ success: true, message: "Session revoked successfully" }),
      {
        status: 200,
        headers: { ...cors_headers, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[revoke-session] Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      {
        status: 500,
        headers: { ...cors_headers, "Content-Type": "application/json" },
      }
    );
  }
});
