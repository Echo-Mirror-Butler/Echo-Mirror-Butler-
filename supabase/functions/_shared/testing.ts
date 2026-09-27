/**
 * Shared Test Utilities & Mocks for Supabase Edge Functions
 *
 * Implements Issue #735:
 * Provides lightweight offline test helpers, fake Supabase clients,
 * and request builders to test edge functions without real network services.
 */

export interface MockSupabaseOptions {
  user?: any;
  authError?: any;
  tableData?: Record<string, any[]>;
  tableErrors?: Record<string, any>;
  rpcResponses?: Record<string, { data?: any; error?: any }>;
}

export function createMockRequest(
  method: string,
  body?: unknown,
  headers?: Record<string, string>,
  url = "http://localhost:3000/test"
): Request {
  const reqHeaders = new Headers();
  reqHeaders.set("Content-Type", "application/json");

  if (headers) {
    for (const [k, v] of Object.entries(headers)) {
      reqHeaders.set(k, v);
    }
  }

  return new Request(url, {
    method,
    headers: reqHeaders,
    body: body !== undefined && method !== "GET" && method !== "HEAD"
      ? (typeof body === "string" ? body : JSON.stringify(body))
      : undefined,
  });
}

export async function getResponseBody(res: Response): Promise<any> {
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function createMockSupabaseClient(options: MockSupabaseOptions = {}) {
  const {
    user = { id: "test-user-id", email: "tester@example.com" },
    authError = null,
    tableData = {},
    tableErrors = {},
    rpcResponses = {},
  } = options;

  return {
    auth: {
      getUser: async (token: string) => {
        if (authError || token === "invalid-token" || !token) {
          return { data: { user: null }, error: authError || new Error("Invalid token") };
        }
        return { data: { user }, error: null };
      },
      resetPasswordForEmail: async (_email: string, _opts?: any) => {
        return { error: null };
      },
    },
    rpc: async (fnName: string, params: any) => {
      if (rpcResponses[fnName]) {
        return rpcResponses[fnName];
      }
      return { data: true, error: null };
    },
    from: (table: string) => {
      const rows = tableData[table] || [];
      const error = tableErrors[table] || null;

      const builder: any = {
        _filters: {},
        select: (_fields?: string, _opts?: any) => builder,
        insert: (_data: any) => builder,
        update: (_data: any) => builder,
        delete: () => builder,
        eq: (col: string, val: any) => {
          builder._filters[col] = val;
          return builder;
        },
        order: (_col: string, _opts?: any) => builder,
        limit: (_n: number) => builder,
        single: async () => {
          if (error) return { data: null, error };
          return { data: rows[0] || null, error: null };
        },
        then: (resolve: any, reject: any) => {
          if (error) return Promise.resolve({ data: null, error }).then(resolve, reject);
          return Promise.resolve({ data: rows, error: null }).then(resolve, reject);
        },
      };

      return builder;
    },
  };
}
