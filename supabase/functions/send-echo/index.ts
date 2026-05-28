import { createClient } from 'npm:@supabase/supabase-js@2';
import * as StellarSdk from 'npm:@stellar/stellar-sdk';

type SendEchoPayload = {
  recipient_user_id: string;
  amount: number;
  message?: string;
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
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Missing or invalid Authorization header' }, 401);
    }

    const supabaseUrl = getEnv('SUPABASE_URL');
    const supabaseAnonKey = getEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required' }, 500);
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );

    if (authError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const payload = (await req.json()) as SendEchoPayload;
    const { recipient_user_id, amount, message } = payload;

    if (!recipient_user_id || typeof recipient_user_id !== 'string') {
      return jsonResponse({ error: 'recipient_user_id is required' }, 400);
    }

    if (recipient_user_id === user.id) {
      return jsonResponse({ error: 'Cannot send ECHO to yourself' }, 400);
    }

    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return jsonResponse({ error: 'amount must be a positive number' }, 400);
    }

    if (amount > 100) {
      return jsonResponse({ error: 'amount must not exceed 100 ECHO' }, 400);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const [senderWallet, recipientWallet] = await Promise.all([
      supabaseAdmin
        .from('user_wallets')
        .select('encrypted_secret, public_key')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabaseAdmin
        .from('user_wallets')
        .select('public_key')
        .eq('user_id', recipient_user_id)
        .maybeSingle(),
    ]);

    if (!senderWallet?.encrypted_secret) {
      return jsonResponse({ error: 'Sender wallet not found or not configured' }, 400);
    }

    if (!recipientWallet?.public_key) {
      return jsonResponse({ error: 'Recipient wallet not found' }, 400);
    }

    const settings = resolveStellarSettings();
    if (!settings.issuerPublicKey) {
      return jsonResponse({ error: 'STELLAR_ISSUER_PUBLIC_KEY is not configured' }, 500);
    }
    if (!settings.walletEncryptionKey) {
      return jsonResponse({ error: 'WALLET_ENCRYPTION_KEY is not configured' }, 500);
    }

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

    const amountStr = amount.toFixed(7);

    const txBuilder = new StellarSdk.TransactionBuilder(account, {
      fee: '100',
      networkPassphrase: settings.networkPassphrase,
    })
      .addOperation(
        StellarSdk.Operation.payment({
          destination: recipientWallet.public_key as string,
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
      return jsonResponse({ error: 'Stellar transaction submission returned no hash' }, 500);
    }

    const txHash = submitResult.hash;

    const { data: giftRow, error: insertError } = await supabaseAdmin
      .from('gift_transactions')
      .insert({
        sender_user_id: user.id,
        recipient_user_id,
        echo_amount: amount,
        stellar_tx_hash: txHash,
        message: message || null,
        status: 'completed',
      })
      .select('*')
      .single();

    if (insertError) {
      console.error('[send-echo] Failed to store gift transaction:', insertError.message);
      return jsonResponse({
        error: 'Transaction submitted but failed to record in database',
        stellar_tx_hash: txHash,
      }, 500);
    }

    return jsonResponse({
      success: true,
      stellar_tx_hash: txHash,
      transaction: giftRow,
    }, 201);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[send-echo] Error:', message);
    return jsonResponse({ error: message }, 500);
  }
});
