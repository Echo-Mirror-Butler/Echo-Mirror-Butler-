import { createClient } from 'npm:@supabase/supabase-js@2';
import * as StellarSdk from 'npm:@stellar/stellar-sdk';

type WebhookRecord = {
  id?: string;
  user_id?: string;
  email?: string;
};

type WebhookPayload = {
  type?: string;
  table?: string;
  schema?: string;
  record?: WebhookRecord;
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
    friendbotUrl: isMainnet ? null : 'https://friendbot.stellar.org',
    issuerPublicKey: getEnv('STELLAR_ISSUER_PUBLIC_KEY'),
    assetCode: getEnv('STELLAR_ASSET_CODE', 'ECHO'),
    walletEncryptionKey: getEnv('WALLET_ENCRYPTION_KEY'),
  };
}

async function importEncryptionKey(rawKey: string) {
  let decoded: Uint8Array;

  try {
    decoded = decodeBase64(rawKey);
  } catch {
    decoded = new TextEncoder().encode(rawKey);
  }

  if (decoded.length !== 32) {
    throw new Error(
      'WALLET_ENCRYPTION_KEY must be a 32-byte value (raw text or base64-encoded)',
    );
  }

  return crypto.subtle.importKey('raw', decoded, 'AES-GCM', false, ['encrypt']);
}

async function encryptSecret(secret: string, rawKey: string) {
  const key = await importEncryptionKey(rawKey);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipherText = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      key,
      new TextEncoder().encode(secret),
    ),
  );

  return JSON.stringify({
    algorithm: 'AES-GCM',
    iv: encodeBase64(iv),
    ciphertext: encodeBase64(cipherText),
  });
}

async function fundViaFriendbot(publicKey: string, friendbotUrl: string) {
  const response = await fetch(
    `${friendbotUrl}?addr=${encodeURIComponent(publicKey)}`,
  );

  if (!response.ok) {
    throw new Error(`Friendbot funding failed: ${await response.text()}`);
  }
}

async function establishTrustline(
  publicKey: string,
  secret: string,
  horizonUrl: string,
  networkPassphrase: string,
  assetCode: string,
  issuerPublicKey: string,
) {
  const server = new StellarSdk.Horizon.Server(horizonUrl);
  const keypair = StellarSdk.Keypair.fromSecret(secret);
  const account = await server.loadAccount(publicKey);
  const asset = new StellarSdk.Asset(assetCode, issuerPublicKey);

  const transaction = new StellarSdk.TransactionBuilder(account, {
    fee: '100',
    networkPassphrase,
  })
    .addOperation(
      StellarSdk.Operation.changeTrust({
        asset,
        limit: '1000000',
      }),
    )
    .setTimeout(30)
    .build();

  transaction.sign(keypair);
  await server.submitTransaction(transaction);
}

async function createWalletForUser(userId: string) {
  const settings = resolveStellarSettings();
  if (!settings.issuerPublicKey) {
    throw new Error('STELLAR_ISSUER_PUBLIC_KEY is not configured');
  }
  if (!settings.walletEncryptionKey) {
    throw new Error('WALLET_ENCRYPTION_KEY is not configured');
  }

  const supabaseUrl = getEnv('SUPABASE_URL');
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: existingWallet, error: existingError } = await supabaseAdmin
    .from('user_wallets')
    .select('id, public_key')
    .eq('user_id', userId)
    .maybeSingle();

  if (existingError) {
    throw new Error(`Failed to check for an existing wallet: ${existingError.message}`);
  }

  if (existingWallet) {
    return {
      alreadyExists: true,
      walletId: existingWallet.id,
      publicKey: existingWallet.public_key,
      funded: false,
      trustlineCreated: true,
    };
  }

  const keypair = StellarSdk.Keypair.random();
  const publicKey = keypair.publicKey();
  const secretKey = keypair.secret();

  if (settings.friendbotUrl) {
    await fundViaFriendbot(publicKey, settings.friendbotUrl);
  }

  await establishTrustline(
    publicKey,
    secretKey,
    settings.horizonUrl,
    settings.networkPassphrase,
    settings.assetCode,
    settings.issuerPublicKey,
  );

  const encryptedSecret = await encryptSecret(
    secretKey,
    settings.walletEncryptionKey,
  );

  const { data: insertedWallet, error: insertError } = await supabaseAdmin
    .from('user_wallets')
    .insert({
      user_id: userId,
      public_key: publicKey,
      encrypted_secret: encryptedSecret,
    })
    .select('id, public_key')
    .single();

  if (insertError || !insertedWallet) {
    throw new Error(
      `Failed to store wallet: ${insertError?.message ?? 'unknown error'}`,
    );
  }

  return {
    alreadyExists: false,
    walletId: insertedWallet.id,
    publicKey: insertedWallet.public_key,
    funded: Boolean(settings.friendbotUrl),
    trustlineCreated: true,
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return jsonResponse({ ok: true });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const payload = (await req.json()) as WebhookPayload;

    if (payload.schema !== 'auth' || payload.table !== 'users') {
      return jsonResponse({ error: 'Unsupported webhook source' }, 400);
    }

    if (payload.type !== 'INSERT') {
      return jsonResponse({ error: 'Unsupported webhook event' }, 400);
    }

    const userId = payload.record?.id ?? payload.record?.user_id;
    if (!userId) {
      return jsonResponse({ error: 'Webhook payload is missing user id' }, 400);
    }

    const result = await createWalletForUser(userId);

    return jsonResponse(
      {
        message: result.alreadyExists
          ? 'Wallet already exists for this user'
          : 'Wallet created successfully',
        ...result,
      },
      result.alreadyExists ? 200 : 201,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[create-stellar-wallet] Error:', message);

    return jsonResponse({ error: message }, 500);
  }
});
