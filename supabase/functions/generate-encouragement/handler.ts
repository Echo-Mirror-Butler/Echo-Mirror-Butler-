/**
 * Request handler for `generate-encouragement`, separated from `index.ts` so it
 * can be called without starting a server: `index.ts` only wires it to
 * `serve()`, the tests import this module with the network and the environment
 * injected (issue #735).
 */

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export const GEMINI_MODEL = "gemini-2.0-flash-exp";
export const FALLBACK_MESSAGE = "Others nearby are feeling similar. You're not alone!";

export interface GenerateEncouragementDeps {
  fetch: typeof fetch;
  /** Injected so tests never read the real environment. */
  env: (name: string) => string | undefined;
}

export interface EncouragementPayload {
  sentiment: string;
  nearbyCount: number;
}

function respond(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * Both fields are required: without them the prompt used to be built from
 * `undefined` ("feeling undefined", "undefined others nearby") and the model was
 * still asked, so a client sending nothing got a 200 and a nonsense message.
 */
export function parsePayload(raw: unknown): { value?: EncouragementPayload; error?: string } {
  if (typeof raw !== "object" || raw === null) return { error: "Request body must be a JSON object" };

  const { sentiment, nearbyCount } = raw as Record<string, unknown>;
  if (typeof sentiment !== "string" || sentiment.trim() === "") {
    return { error: "sentiment is required and must be a non-empty string" };
  }
  if (typeof nearbyCount !== "number" || !Number.isFinite(nearbyCount) || nearbyCount < 0) {
    return { error: "nearbyCount is required and must be a non-negative number" };
  }
  return { value: { sentiment, nearbyCount } };
}

export async function handleRequest(req: Request, deps: GenerateEncouragementDeps): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return respond({ error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, 405);
  }

  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return respond({ error: "Invalid JSON body", code: "INVALID_BODY" }, 400);
  }

  const parsed = parsePayload(raw);
  if (parsed.error) {
    return respond({ error: parsed.error, code: "INVALID_PAYLOAD" }, 400);
  }
  const { sentiment, nearbyCount } = parsed.value!;

  const apiKey = deps.env("GEMINI_API_KEY");
  if (!apiKey) {
    // A missing key is a deployment problem, not something the caller did: it
    // used to be reported as 400 like every other failure.
    console.error("[generate-encouragement] GEMINI_API_KEY is not set");
    return respond({ error: "Server is not configured", code: "CONFIG_ERROR" }, 500);
  }

  const prompt = `Write a short, uplifting encouraging message for someone feeling ${sentiment}. Mention that ${nearbyCount} others nearby might be feeling similar, to build a sense of community. Keep it to 1 sentence.`;

  let response: Response;
  try {
    response = await deps.fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
      },
    );
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    console.error("[generate-encouragement] Gemini request failed:", details);
    return respond({ error: "Failed to reach the language model", code: "UPSTREAM_UNAVAILABLE", details }, 502);
  }

  if (!response.ok) {
    console.error("[generate-encouragement] Gemini API error:", response.status, response.statusText);
    // An upstream failure is not a bad request from the caller.
    return respond(
      { error: "Language model request failed", code: "UPSTREAM_ERROR", status: response.status },
      502,
    );
  }

  let data: { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
  try {
    data = await response.json();
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return respond({ error: "Language model returned invalid JSON", code: "UPSTREAM_BAD_BODY", details }, 502);
  }

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || FALLBACK_MESSAGE;
  return respond({ message: text }, 200);
}
