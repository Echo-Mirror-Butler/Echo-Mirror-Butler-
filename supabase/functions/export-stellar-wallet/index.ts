import { createClient } from 'npm:@supabase/supabase-js@2';
import * as StellarSdk from 'npm:@stellar/stellar-sdk';

type ExportRequest = {
  password?: string;
  acknowledge_risks?: boolean;
};

const jsonHeaders = {
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store, no-cache, must-revalidate, private',
  Pragma: 'no-cache',
  'Referrer-Policy': 'no-referrer',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function env(name: string) {
  return Deno.env.get(name) ?? '';
}

function decodeBase64(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, character => character.charCodeAt(0));
}

function decodeBase64Url(value: string) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  return decodeBase64(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
}

function readAal(accessToken: string): string | null {
  try {
    const payload = accessToken.split('.')[1];
    if (!payload) return null;
    const decoded = new TextDecoder().decode(decodeBase64Url(payload));
    return (JSON.parse(decoded) as { aal?: string }).aal ?? null;
  } catch {
    return null;
  }
}

async function importDecryptionKey(rawKey: string) {
  let decoded: Uint8Array;
  try {
    decoded = decodeBase64(rawKey);
  } catch {
    decoded = new TextEncoder().encode(rawKey);
  }

  if (decoded.length !== 32) {
    throw new Error('WALLET_ENCRYPTION_KEY must contain exactly 32 bytes');
  }
  return crypto.subtle.importKey('raw', decoded, 'AES-GCM', false, ['decrypt']);
}

async function resolveSecret(encryptedSecret: string, encryptionKey: string) {
  // Older wallets were stored before envelope encryption was introduced.
  // Validate those values as Stellar secrets instead of attempting to parse
  // them, while all newer JSON payloads must decrypt with AES-GCM.
  if (!encryptedSecret.trim().startsWith('{')) {
    StellarSdk.Keypair.fromSecret(encryptedSecret);
    return encryptedSecret;
  }

  const payload = JSON.parse(encryptedSecret) as {
    algorithm?: string;
    iv?: string;
    ciphertext?: string;
  };
  if (
    payload.algorithm !== 'AES-GCM' ||
    !payload.iv ||
    !payload.ciphertext
  ) {
    throw new Error('Unsupported wallet encryption payload');
  }

  const key = await importDecryptionKey(encryptionKey);
  const plaintext = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: decodeBase64(payload.iv) },
    key,
    decodeBase64(payload.ciphertext),
  );
  return new TextDecoder().decode(plaintext);
}

Deno.serve(async request => {
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed', code: 'METHOD_NOT_ALLOWED' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return json({ error: 'Authentication required', code: 'UNAUTHORIZED' }, 401);
  }

  const supabaseUrl = env('SUPABASE_URL');
  const anonKey = env('SUPABASE_ANON_KEY');
  const serviceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
  const encryptionKey = env('WALLET_ENCRYPTION_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !encryptionKey) {
    return json({ error: 'Wallet export is unavailable', code: 'SERVER_CONFIG_ERROR' }, 503);
  }

  const accessToken = authorization.slice('Bearer '.length);
  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await authClient.auth.getUser(
    accessToken,
  );
  const user = userData.user;
  if (userError || !user) {
    return json({ error: 'Authentication required', code: 'UNAUTHORIZED' }, 401);
  }

  let body: ExportRequest;
  try {
    body = await request.json() as ExportRequest;
  } catch {
    return json({ error: 'Invalid request body', code: 'INVALID_BODY' }, 400);
  }

  if (!body.password || body.acknowledge_risks !== true) {
    return json({
      error: 'Password and security-risk acknowledgement are required',
      code: 'REAUTH_REQUIRED',
    }, 400);
  }

  if (!user.email) {
    return json({
      error: 'Password reauthentication is unavailable for this account',
      code: 'PASSWORD_REAUTH_UNAVAILABLE',
    }, 409);
  }

  const factors = (user as typeof user & {
    factors?: Array<{ status?: string }>;
  }).factors ?? [];
  const hasVerifiedMfa = factors.some(factor => factor.status === 'verified');
  if (hasVerifiedMfa && readAal(accessToken) !== 'aal2') {
    return json({
      error: 'Complete two-factor authentication before exporting your wallet',
      code: 'MFA_REQUIRED',
    }, 403);
  }

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: recentExports } = await admin
    .from('wallet_export_events')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('outcome', 'SUCCEEDED')
    .gte('created_at', oneHourAgo);
  if ((recentExports ?? 0) >= 3) {
    return json({
      error: 'Wallet export limit reached. Try again later.',
      code: 'RATE_LIMITED',
    }, 429);
  }

  const { data: reauth, error: reauthError } = await authClient.auth
    .signInWithPassword({ email: user.email, password: body.password });
  if (reauthError || reauth.user?.id !== user.id) {
    await admin.from('wallet_export_events').insert({
      user_id: user.id,
      outcome: 'DENIED',
      reason: 'password_reauthentication_failed',
    });
    return json({ error: 'Password verification failed', code: 'REAUTH_FAILED' }, 403);
  }

  const { data: wallet, error: walletError } = await admin
    .from('user_wallets')
    .select('public_key, encrypted_secret')
    .eq('user_id', user.id)
    .maybeSingle();
  if (walletError || !wallet?.encrypted_secret || !wallet.public_key) {
    return json({ error: 'Wallet not found', code: 'WALLET_NOT_FOUND' }, 404);
  }

  try {
    const secretKey = await resolveSecret(wallet.encrypted_secret, encryptionKey);
    const derivedPublicKey = StellarSdk.Keypair.fromSecret(secretKey).publicKey();
    if (derivedPublicKey !== wallet.public_key) {
      throw new Error('Stored secret does not match the wallet public key');
    }

    const { data: event } = await admin.from('wallet_export_events').insert({
      user_id: user.id,
      public_key: wallet.public_key,
      outcome: 'SUCCEEDED',
      mfa_verified: hasVerifiedMfa,
    }).select('id').single();

    return json({
      public_key: wallet.public_key,
      secret_key: secretKey,
      export_event_id: event?.id,
      network: env('STELLAR_NETWORK') || 'testnet',
      security_notice: [
        'Never screenshot or share this secret key.',
        'Anyone with this key has irreversible control of your funds.',
        'Import it into a trusted Stellar wallet and verify access before completing migration.',
      ],
    });
  } catch {
    await admin.from('wallet_export_events').insert({
      user_id: user.id,
      public_key: wallet.public_key,
      outcome: 'FAILED',
      reason: 'secret_validation_failed',
    });
    return json({
      error: 'The stored wallet could not be safely exported',
      code: 'EXPORT_VALIDATION_FAILED',
    }, 500);
  }
});
