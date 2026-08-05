import { createClient } from 'npm:@supabase/supabase-js@2';
import * as StellarSdk from 'npm:@stellar/stellar-sdk';
import {
  extractIdempotencyKey,
  checkIdempotency,
  storeIdempotencyResult,
  buildReplayedResponse,
} from '../_shared/idempotency.ts';

type SendEchoPayload = {
  recipient_id?: string;
  recipient_user_id?: string;
  amount: number;
  message?: string;
  // Clients may also pass the idempotency key in the body as a fallback,
  // but the preferred location is the `Idempotency-Key` HTTP header.
  idempotency_key?: string;
};

const jsonHeaders = {
  'Content-Type': 'application/json',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function getEnv(name: string, fallback = '') {
  return Deno.env.get(name) ?? fallback;
}

function decodeBase64(value: string) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function encodeBase64(bytes: Uint8Array) {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function resolveStellarSettings() {
  const network = getEnv('STELLAR_NETWORK', 'testnet').toLowerCase();
  const isMainnet = network === 'mainnet';

  return {
    network,
    horizonUrl: isMainnet
      ? 'https://horizon.stellar.org'
      : 'https://horizon-testnet.stellar.org',
    networkPassphrase: isMainnet
      ? StellarSdk.Networks.PUBLIC
      : StellarSdk.Networks.TESTNET,
    issuerPublicKey: getEnv('STELLAR_ISSUER_PUBLIC_KEY'),
    assetCode: getEnv('STELLAR_ASSET_CODE', 'ECHO'),
    walletEncryptionKey: getEnv('WALLET_ENCRYPTION_KEY'),
  };
}

async function importDecryptionKey(rawKey: string) {
  let decoded: Uint8Array;

  try {
    decoded = decodeBase64(rawKey);
  } catch {
    decoded = new TextEncoder().encode(rawKey);
  }

  if (decoded.length !== 32) {
    throw new Error('WALLET_ENCRYPTION_KEY must be a 32-byte value');
  }

  return crypto.subtle.importKey('raw', decoded, 'AES-GCM', false, ['decrypt']);
}

async function decryptSecret(encryptedPayload: string, rawKey: string) {
  const { algorithm, iv, ciphertext } = JSON.parse(encryptedPayload) as {
    algorithm: string;
    iv: string;
    ciphertext: string;
  };

  if (algorithm !== 'AES-GCM') {
    throw new Error(`Unsupported encryption algorithm: ${algorithm}`);
  }

  const key = await importDecryptionKey(rawKey);
  const ivBytes = decodeBase64(iv);
  const cipherBytes = decodeBase64(ciphertext);

  const plainBytes = new Uint8Array(
    await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: ivBytes },
      key,
      cipherBytes,
    ),
  );

  return new TextDecoder().decode(plainBytes);
}

Deno.serve(async (req) => {
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
    const supabaseAnonKey = getEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required',
        code: 'SERVER_CONFIG_ERROR',
      }, 500);
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Create the admin client early so it can be shared across all DB calls,
    // including the idempotency cache lookup that happens before payload parsing.
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );

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
        supabaseAdmin,
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
    const { data: recipientProfile, error: recipientError } = await supabaseAdmin
      .from('user_wallets')
      .select('public_key, user_id')
      .eq('user_id', recipientUserId)
      .maybeSingle();

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
    const { data: rateAllowed, error: rateError } = await supabaseAdmin.rpc(
      'check_rate_limit',
      {
        p_user_id: user.id,
        p_action: 'send_echo',
        p_max_count: 10,
        p_window_hours: 1.0,
      },
    );

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
    const { data: senderWallet, error: senderWalletError } = await supabaseAdmin
      .from('user_wallets')
      .select('encrypted_secret, public_key, balance')
      .eq('user_id', user.id)
      .maybeSingle();

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

    const settings = resolveStellarSettings();
    if (!settings.issuerPublicKey) {
      return jsonResponse({ error: 'STELLAR_ISSUER_PUBLIC_KEY is not configured', code: 'SERVER_CONFIG_ERROR' }, 500);
    }
    if (!settings.walletEncryptionKey) {
      return jsonResponse({ error: 'WALLET_ENCRYPTION_KEY is not configured', code: 'SERVER_CONFIG_ERROR' }, 500);
    }

    // ── Submit Stellar transaction ──
    const senderSecret = await decryptSecret(
      senderWallet.encrypted_secret as string,
      settings.walletEncryptionKey,
    );

    const server = new StellarSdk.Horizon.Server(settings.horizonUrl);
    const senderKeypair = StellarSdk.Keypair.fromSecret(senderSecret);
    const account = await server.loadAccount(senderKeypair.publicKey());

    const echoAsset = new StellarSdk.Asset(
      settings.assetCode,
      settings.issuerPublicKey,
    );

    const amountStr = intAmount.toFixed(7);

    const txBuilder = new StellarSdk.TransactionBuilder(account, {
      fee: '100',
      networkPassphrase: settings.networkPassphrase,
    })
      .addOperation(
        StellarSdk.Operation.payment({
          destination: recipientProfile.public_key as string,
          asset: echoAsset,
          amount: amountStr,
        }),
      );

    if (message && message.length > 0) {
      const truncatedMemo = message.length > 28
        ? message.substring(0, 28)
        : message;
      txBuilder.addMemo(StellarSdk.Memo.text(truncatedMemo));
    }

    const transaction = txBuilder.setTimeout(30).build();
    transaction.sign(senderKeypair);

    const submitResult = await server.submitTransaction(transaction);

    if (!submitResult.hash) {
      return jsonResponse({ error: 'Stellar transaction submission returned no hash', code: 'STELLAR_ERROR' }, 500);
    }

    const txHash = submitResult.hash;

    // ── Atomic balance update + audit log via RPC ──
    const { data: rpcResult, error: rpcError } = await supabaseAdmin.rpc(
      'complete_echo_transfer',
      {
        p_sender_id: user.id,
        p_recipient_id: recipientUserId,
        p_amount: intAmount,
        p_stellar_tx_hash: txHash,
        p_message: message || null,
      },
    );

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
    const { data: giftRow, error: fetchError } = await supabaseAdmin
      .from('gift_transactions')
      .select('*')
      .eq('id', rpcResult.gift_id)
      .single();

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
        supabaseAdmin,
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
});