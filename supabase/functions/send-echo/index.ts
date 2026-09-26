import { createClient } from 'npm:@supabase/supabase-js@2';
import * as StellarSdk from 'npm:@stellar/stellar-sdk';
import { handleRequest, type SendEchoDeps } from './handler.ts';

/**
 * Runtime wiring for `send-echo`: builds the real dependencies (Supabase
 * clients, secret decryption, the Stellar Horizon adapter) and hands them to
 * the pure handler in `handler.ts`, which the offline tests import directly
 * with fakes (issue #735). Behaviour is unchanged from the previous inline
 * implementation. No side effects at module scope — clients are created when
 * the server starts serving.
 */

function getEnv(name: string, fallback = ''): string {
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

const NETWORK_PASSPHRASES = {
  mainnet: 'Public Global Stellar Network ; September 2015',
  testnet: 'Test SDF Network ; September 2015',
};

function createRuntimeDeps(): SendEchoDeps {
  const supabaseClient = createClient(getEnv('SUPABASE_URL'), getEnv('SUPABASE_ANON_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const supabaseAdmin = createClient(getEnv('SUPABASE_URL'), getEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    env: (name) => {
      const value = Deno.env.get(name);
      return value === undefined ? undefined : value;
    },
    supabaseAdmin,
    getUser: async (token) => await supabaseClient.auth.getUser(token),
    decryptSecret,
    sendStellarPayment: async (args) => {
      const server = new StellarSdk.Horizon.Server(args.horizonUrl);
      const senderKeypair = StellarSdk.Keypair.fromSecret(args.senderSecret);
      const account = await server.loadAccount(senderKeypair.publicKey());

      const echoAsset = new StellarSdk.Asset(args.assetCode, args.issuerPublicKey);

      const txBuilder = new StellarSdk.TransactionBuilder(account, {
        fee: '100',
        networkPassphrase: args.networkPassphrase as StellarSdk.Networks['PUBLIC'],
      })
        .addOperation(
          StellarSdk.Operation.payment({
            destination: args.recipientPublicKey,
            asset: echoAsset,
            amount: args.amount.toFixed(7),
          }),
        );

      if (args.memo) {
        txBuilder.addMemo(StellarSdk.Memo.text(args.memo));
      }

      const transaction = txBuilder.setTimeout(30).build();
      transaction.sign(senderKeypair);

      const submitResult = await server.submitTransaction(transaction);

      if (!submitResult.hash) {
        throw new Error('Stellar transaction submission returned no hash');
      }

      return submitResult.hash;
    },
  };
}

Deno.serve((req) => handleRequest(req, createRuntimeDeps()));

export { NETWORK_PASSPHRASES };
