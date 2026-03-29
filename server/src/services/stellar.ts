import {
  Asset,
  Horizon,
  Keypair,
  Memo,
  Networks,
  Operation,
  TransactionBuilder,
} from '@stellar/stellar-sdk';

const horizonUrl =
  process.env.STELLAR_HORIZON_URL ?? 'https://horizon-testnet.stellar.org';
const networkPassphrase =
  process.env.STELLAR_NETWORK_PASSPHRASE ?? Networks.TESTNET;
const assetCode = process.env.STELLAR_ASSET_CODE ?? 'ECHO';
const issuerPublic = process.env.STELLAR_ISSUER_PUBLIC ?? '';
const friendbotUrl = 'https://friendbot.stellar.org';

const server = new Horizon.Server(horizonUrl);

function getEchoAsset(): Asset {
  if (!issuerPublic) {
    throw new Error('STELLAR_ISSUER_PUBLIC is not configured');
  }
  return new Asset(assetCode, issuerPublic);
}

export interface WalletBalance {
  xlm: string;
  echo: string;
}

export interface GiftResult {
  txHash: string;
  amount: string;
  recipient: string;
}

export async function createWallet(): Promise<{
  publicKey: string;
  secretKey: string;
}> {
  const keypair = Keypair.random();

  const response = await fetch(`${friendbotUrl}?addr=${keypair.publicKey()}`);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Friendbot funding failed: ${body}`);
  }

  return {
    publicKey: keypair.publicKey(),
    secretKey: keypair.secret(),
  };
}

export async function establishTrustline(secretKey: string): Promise<void> {
  const keypair = Keypair.fromSecret(secretKey);
  const account = await server.loadAccount(keypair.publicKey());

  const tx = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase,
  })
    .addOperation(
      Operation.changeTrust({
        asset: getEchoAsset(),
        limit: '1000000',
      }),
    )
    .setTimeout(30)
    .build();

  tx.sign(keypair);
  await server.submitTransaction(tx);
}

export async function getWalletBalances(
  publicKey: string,
): Promise<WalletBalance> {
  const account = await server.loadAccount(publicKey);

  let xlm = '0';
  let echo = '0';

  for (const balance of account.balances) {
    if (balance.asset_type === 'native') {
      xlm = balance.balance;
    } else if (
      balance.asset_type === 'credit_alphanum4' &&
      balance.asset_code === assetCode &&
      balance.asset_issuer === issuerPublic
    ) {
      echo = balance.balance;
    }
  }

  return { xlm, echo };
}

export async function sendEcho(
  senderSecret: string,
  recipientPublicKey: string,
  amount: string,
  memo?: string,
): Promise<GiftResult> {
  const senderKeypair = Keypair.fromSecret(senderSecret);
  const account = await server.loadAccount(senderKeypair.publicKey());

  const builder = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase,
  }).addOperation(
    Operation.payment({
      destination: recipientPublicKey,
      asset: getEchoAsset(),
      amount,
    }),
  );

  if (memo) {
    const truncated = memo.length > 28 ? memo.slice(0, 28) : memo;
    builder.addMemo(Memo.text(truncated));
  }

  const tx = builder.setTimeout(30).build();
  tx.sign(senderKeypair);

  const result = await server.submitTransaction(tx);

  return {
    txHash: result.hash,
    amount,
    recipient: recipientPublicKey,
  };
}

