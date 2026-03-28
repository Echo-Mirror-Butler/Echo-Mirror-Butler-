"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.echoAsset = void 0;
exports.createWallet = createWallet;
exports.establishTrustline = establishTrustline;
exports.getWalletBalances = getWalletBalances;
exports.sendEcho = sendEcho;
const stellar_sdk_1 = require("@stellar/stellar-sdk");
const horizonUrl = process.env.STELLAR_HORIZON_URL ?? 'https://horizon-testnet.stellar.org';
const networkPassphrase = process.env.STELLAR_NETWORK_PASSPHRASE ?? stellar_sdk_1.Networks.TESTNET;
const assetCode = process.env.STELLAR_ASSET_CODE ?? 'ECHO';
const issuerPublic = process.env.STELLAR_ISSUER_PUBLIC ?? '';
const friendbotUrl = 'https://friendbot.stellar.org';
const server = new stellar_sdk_1.Server(horizonUrl);
exports.echoAsset = new stellar_sdk_1.Asset(assetCode, issuerPublic);
/**
 * Generates a new Stellar keypair and funds it via Friendbot (testnet only).
 */
async function createWallet() {
    const keypair = stellar_sdk_1.Keypair.random();
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
/**
 * Establishes a trustline so the wallet can hold ECHO tokens.
 */
async function establishTrustline(secretKey) {
    if (!issuerPublic)
        throw new Error('STELLAR_ISSUER_PUBLIC is not configured');
    const keypair = stellar_sdk_1.Keypair.fromSecret(secretKey);
    const account = await server.loadAccount(keypair.publicKey());
    const tx = new stellar_sdk_1.TransactionBuilder(account, {
        fee: '100',
        networkPassphrase,
    })
        .addOperation(stellar_sdk_1.Operation.changeTrust({
        asset: exports.echoAsset,
        limit: '1000000',
    }))
        .setTimeout(30)
        .build();
    tx.sign(keypair);
    await server.submitTransaction(tx);
}
/**
 * Returns XLM and ECHO balances for the given public key.
 */
async function getWalletBalances(publicKey) {
    const account = await server.loadAccount(publicKey);
    let xlm = '0';
    let echo = '0';
    for (const balance of account.balances) {
        if (balance.asset_type === 'native') {
            xlm = balance.balance;
        }
        else if (balance.asset_type === 'credit_alphanum4' &&
            balance.asset_code === assetCode &&
            balance.asset_issuer === issuerPublic) {
            echo = balance.balance;
        }
    }
    return { xlm, echo };
}
/**
 * Sends ECHO tokens from sender to recipient. Returns the transaction hash.
 */
async function sendEcho(senderSecret, recipientPublicKey, amount, memo) {
    if (!issuerPublic)
        throw new Error('STELLAR_ISSUER_PUBLIC is not configured');
    const senderKeypair = stellar_sdk_1.Keypair.fromSecret(senderSecret);
    const account = await server.loadAccount(senderKeypair.publicKey());
    const builder = new stellar_sdk_1.TransactionBuilder(account, {
        fee: '100',
        networkPassphrase,
    }).addOperation(stellar_sdk_1.Operation.payment({
        destination: recipientPublicKey,
        asset: exports.echoAsset,
        amount,
    }));
    if (memo) {
        const truncated = memo.length > 28 ? memo.slice(0, 28) : memo;
        builder.addMemo(stellar_sdk_1.Memo.text(truncated));
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
