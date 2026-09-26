import {
  buildReplayedResponse,
  checkIdempotency,
  extractIdempotencyKey,
  storeIdempotencyResult,
} from '../_shared/idempotency.ts';

/**
 * Request handler for `send-echo`, separated from `index.ts` so it can be
 * called without starting a server. Everything external (Supabase clients,
 * auth, the clock, secrets, Stellar) arrives through `deps`, so the tests
 * import this module with fakes and never touch a real service (issue #735).
 * The runtime wiring (real clients + the real Stellar adapter) lives in
 * `index.ts`.
 */

type SendEchoPayload = {
  recipient_id?: string;
  recipient_user_id?: string;
  amount: number;
  message?: string;
  // Clients may also pass the idempotency key in the body as a fallback,
  // but the preferred location is the `Idempotency-Key` HTTP header.
  idempotency_key?: string;
};

export interface SendEchoDeps {
  /** Reads configuration; the tests supply an in-memory map. */
  env: (name: string) => string | undefined;
  /** Admin client used for all DB access, including idempotency. */
  supabaseAdmin: unknown;
  /** Validates a bearer token and returns the authenticated user id. */
  getUser: (
    token: string,
  ) => Promise<{ user: { id: string } | null; error: { message: string } | null }>;
  /** Decrypts the sender's stored wallet secret. */
  decryptSecret: (encryptedPayload: string, rawKey: string) => Promise<string>;
  /**
   * Submits the Stellar payment and resolves with the transaction hash.
   * Throws on any network/submission failure — the handler maps that to 502.
   */
  sendStellarPayment: (args: {
    horizonUrl: string;
    networkPassphrase: string;
    senderSecret: string;
    recipientPublicKey: string;
    assetCode: string;
    issuerPublicKey: string;
    amount: number;
    memo?: string;
  }) => Promise<string>;
}

const jsonHeaders = {
  'Content-Type': 'application/json',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

export async function handleRequest(req: Request, deps: SendEchoDeps): Promise<Response> {
  const getEnv = (name: string, fallback = ''): string => deps.env(name) ?? fallback;

  if (req.method === 'OPTIONS') {
    return jsonResponse({ ok: true });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed', code: 'METHOD_NOT_ALLOWED' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Missing or invalid Authorization header', code: 'UNAUTHORIZED' }, 401);
    }

    const supabaseUrl = getEnv('SUPABASE_URL');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required',
        code: 'SERVER_CONFIG_ERROR',
      }, 500);
    }

    const supabaseAdmin = deps.supabaseAdmin as {
      from: (table: string) => unknown;
      rpc: (name: string, args?: unknown) => unknown;
    };

    const { user, error: authError } = await deps.getUser(authHeader.replace('Bearer ', ''));

    if (authError || !user) {
      return jsonResponse({ error: 'Unauthorized', code: 'UNAUTHORIZED' }, 401);
    }

    // ── Idempotency: extract key (header takes precedence over body field) ──
    // The key is optional — requests without it are processed normally.
    // When present the first execution's result is cached for 24 hours;
    // retries with the same key receive the cached response immediately.
    const idempotencyKey = extractIdempotencyKey(req);

    // ── Parse and validate payload ──
    let payload: SendEchoPayload;
    try {
      payload = (await req.json()) as SendEchoPayload;
    } catch {
      return jsonResponse({ error: 'Invalid JSON body', code: 'INVALID_BODY' }, 400);
    }

    // Allow body-supplied key as fallback (header wins if both are present)
    const resolvedIdempotencyKey = idempotencyKey ?? payload.idempotency_key?.trim() ?? null;

    // ── Idempotency cache check ──
    if (resolvedIdempotencyKey) {
      const cached = await checkIdempotency(
        supabaseAdmin as never,
        user.id,
        'send-echo',
        resolvedIdempotencyKey,
      );

      if (cached.hit) {
        console.log(
          `[send-echo] Idempotency cache hit for user=${user.id} key=${resolvedIdempotencyKey}`,
        );
        return buildReplayedResponse(cached.body, cached.status);
      }
    }

    const { recipient_id, recipient_user_id, amount, message } = payload;
    const recipientUserId = recipient_id ?? recipient_user_id;

    // ── Self-send prevention ──
    if (!recipientUserId || typeof recipientUserId !== 'string') {
      return jsonResponse({ error: 'recipient_id is required', code: 'MISSING_FIELD' }, 400);
    }

    if (recipientUserId === user.id) {
      return jsonResponse({ error: 'Cannot send ECHO to yourself', code: 'SELF_SEND' }, 400);
    }

    // ── Amount validation ──
    if (amount === undefined || amount === null || typeof amount !== 'number' || isNaN(amount)) {
      return jsonResponse({ error: 'amount must be a valid number', code: 'INVALID_AMOUNT' }, 400);
    }

    if (amount <= 0) {
      return jsonResponse({ error: 'amount must be a positive number', code: 'INVALID_AMOUNT' }, 400);
    }

    if (amount > 100) {
      return jsonResponse({ error: 'amount must not exceed 100 ECHO', code: 'AMOUNT_EXCEEDS_LIMIT' }, 400);
    }

    // Round to integer (ECHO balances are integer in the database)
    const intAmount = Math.floor(amount);

    if (intAmount <= 0) {
      return jsonResponse({ error: 'amount rounds down to 0', code: 'INVALID_AMOUNT' }, 400);
    }

    // ── Recipient validation ──
    const { data: recipientProfile, error: recipientError } = (await (supabaseAdmin
      .from('user_wallets') as {
      select: (...args: unknown[]) => unknown;
    })
      .select('public_key, user_id')
      .eq('user_id', recipientUserId)
      .maybeSingle()) as {
      data: { public_key: string; user_id: string } | null;
      error: { message: string } | null;
    };

    if (recipientError) {
      console.error('[send-echo] Recipient lookup error:', recipientError.message);
      return jsonResponse({ error: 'Failed to verify recipient', code: 'INTERNAL_ERROR' }, 500);
    }

    if (!recipientProfile) {
      return jsonResponse({
        error: 'Recipient not found — they need to create a wallet first',
        code: 'RECIPIENT_NOT_FOUND',
      }, 404);
    }

    // ── Rate limiting ──
    const { data: rateAllowed, error: rateError } = (await supabaseAdmin.rpc(
      'check_rate_limit',
      {
        p_user_id: user.id,
        p_action: 'send_echo',
        p_max_count: 10,
        p_window_hours: 1.0,
      },
    )) as { data: boolean | null; error: { message: string } | null };

    if (rateError) {
      console.error('[send-echo] Rate limit check error:', rateError.message);
      // Don't block the transfer if rate limiting fails — log and proceed
    } else if (rateAllowed === false) {
      return jsonResponse({
        error: 'Rate limit exceeded. Maximum 10 ECHO transfers per hour allowed.',
        code: 'RATE_LIMITED',
      }, 429);
    }

    // ── Get sender wallet for Stellar transaction ──
    const { data: senderWallet, error: senderWalletError } = (await (supabaseAdmin
      .from('user_wallets') as {
      select: (...args: unknown[]) => unknown;
    })
      .select('encrypted_secret, public_key, balance')
      .eq('user_id', user.id)
      .maybeSingle()) as {
      data: { encrypted_secret: string; public_key: string; balance: number } | null;
      error: { message: string } | null;
    };

    if (senderWalletError) {
      console.error('[send-echo] Sender wallet lookup error:', senderWalletError.message);
      return jsonResponse({ error: 'Failed to fetch sender wallet', code: 'INTERNAL_ERROR' }, 500);
    }

    if (!senderWallet?.encrypted_secret) {
      return jsonResponse({ error: 'Sender wallet not found or not configured', code: 'SENDER_WALLET_NOT_FOUND' }, 400);
    }

    // ── Balance check before Stellar (double-check, RPC also checks) ──
    if (senderWallet.balance < intAmount) {
      return jsonResponse({ error: 'Insufficient balance', code: 'INSUFFICIENT_BALANCE' }, 400);
    }

    const walletEncryptionKey = getEnv('WALLET_ENCRYPTION_KEY');
    const issuerPublicKey = getEnv('STELLAR_ISSUER_PUBLIC_KEY');
    const assetCode = getEnv('STELLAR_ASSET_CODE', 'ECHO');

    if (!issuerPublicKey) {
      return jsonResponse({ error: 'STELLAR_ISSUER_PUBLIC_KEY is not configured', code: 'SERVER_CONFIG_ERROR' }, 500);
    }
    if (!walletEncryptionKey) {
      return jsonResponse({ error: 'WALLET_ENCRYPTION_KEY is not configured', code: 'SERVER_CONFIG_ERROR' }, 500);
    }

    // ── Submit Stellar transaction ──
    const senderSecret = await deps.decryptSecret(
      senderWallet.encrypted_secret as string,
      walletEncryptionKey,
    );

    // Stellar is an external service: a submission failure is an upstream
    // problem, not a client error, so it maps to 502 instead of falling into
    // the generic 500 catch-all (and never to 400).
    let txHash: string;
    try {
      txHash = await deps.sendStellarPayment({
        horizonUrl: getEnv('STELLAR_HORIZON_URL') ||
          (getEnv('STELLAR_NETWORK', 'testnet').toLowerCase() === 'mainnet'
            ? 'https://horizon.stellar.org'
            : 'https://horizon-testnet.stellar.org'),
        networkPassphrase: getEnv('STELLAR_NETWORK', 'testnet').toLowerCase() === 'mainnet'
          ? 'Public Global Stellar Network ; September 2015'
          : 'Test SDF Network ; September 2015',
        senderSecret,
        recipientPublicKey: recipientProfile.public_key as string,
        assetCode,
        issuerPublicKey,
        amount: intAmount,
        memo: message && message.length > 0 ? message.substring(0, 28) : undefined,
      });
    } catch (stellarError) {
      const stellarMessage = stellarError instanceof Error
        ? stellarError.message
        : String(stellarError);
      console.error('[send-echo] Stellar submission failed:', stellarMessage);
      return jsonResponse({ error: stellarMessage, code: 'STELLAR_ERROR' }, 502);
    }

    // ── Atomic balance update + audit log via RPC ──
    const { data: rpcResult, error: rpcError } = (await supabaseAdmin.rpc(
      'complete_echo_transfer',
      {
        p_sender_id: user.id,
        p_recipient_id: recipientUserId,
        p_amount: intAmount,
        p_stellar_tx_hash: txHash,
        p_message: message || null,
      },
    )) as {
      data: { success: boolean; error?: string; code?: string; gift_id?: string } | null;
      error: { message: string } | null;
    };

    if (rpcError) {
      console.error('[send-echo] Atomic transfer RPC failed:', rpcError.message);
      // Stellar tx went through but DB state is inconsistent
      return jsonResponse({
        error: 'Stellar transaction submitted but failed to record in database. Please contact support.',
        code: 'DB_RECORDING_FAILED',
        stellar_tx_hash: txHash,
      }, 500);
    }

    if (!rpcResult?.success) {
      console.error('[send-echo] Atomic transfer RPC returned error:', rpcResult?.error);
      // Stellar tx went through but our validation failed (e.g. balance changed between checks)
      return jsonResponse({
        error: rpcResult?.error || 'Database transfer failed',
        code: rpcResult?.code || 'DB_TRANSFER_FAILED',
        stellar_tx_hash: txHash,
      }, 500);
    }

    // ── Fetch the created gift transaction for the response ──
    const { data: giftRow, error: fetchError } = (await (supabaseAdmin
      .from('gift_transactions') as {
      select: (...args: unknown[]) => unknown;
    })
      .select('*')
      .eq('id', rpcResult.gift_id)
      .single()) as { data: Record<string, unknown> | null; error: { message: string } | null };

    const successBody = {
      success: true,
      stellar_tx_hash: txHash,
      transaction: fetchError ? null : giftRow,
      // Echo back the idempotency key so clients can correlate requests
      ...(resolvedIdempotencyKey ? { idempotency_key: resolvedIdempotencyKey } : {}),
    };

    // ── Store idempotency result (only on full success) ──
    // Stored AFTER both the Stellar tx and the DB RPC succeed so we never
    // cache a partial failure. 5xx errors are intentionally NOT cached so
    // clients can safely retry on network/infra issues.
    if (resolvedIdempotencyKey) {
      await storeIdempotencyResult(
        supabaseAdmin as never,
        user.id,
        'send-echo',
        resolvedIdempotencyKey,
        201,
        successBody,
      );
    }

    return jsonResponse(successBody, 201);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[send-echo] Error:', message);
    return jsonResponse({
      error: message,
      code: 'INTERNAL_ERROR',
    }, 500);
  }
}
