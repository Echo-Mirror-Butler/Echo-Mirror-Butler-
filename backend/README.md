# EchoMirror Backend — Stellar Integration

This folder contains the Stellar blockchain integration for the **ECHO token**, the in-app currency used in the Global Mirror gifting feature.

## What is ECHO?

ECHO is a custom Stellar asset on the testnet. Users earn ECHO by participating in the Global Mirror:
- Sharing a mood pin → **+2 ECHO**
- Posting a video → **+5 ECHO**
- Receiving a comment on your pin → **+1 ECHO**
- New user welcome bonus → **+10 ECHO**

Users can gift ECHO to other users to show appreciation directly from the Global Mirror.

---

## File Structure

```
backend/
├── stellar/
│   ├── stellar_config.dart    # Network config, asset code, Horizon URL
│   ├── echo_token.dart        # ECHO asset definition and reward constants
│   └── stellar_service.dart   # Wallet creation, trustlines, payments
└── .env.example               # Environment variable template
```

---

## Network Details

| Setting      | Value                                  |
|--------------|----------------------------------------|
| Network      | Stellar Testnet                        |
| Horizon URL  | https://horizon-testnet.stellar.org    |
| Asset Code   | ECHO                                   |
| Friendbot    | https://friendbot.stellar.org          |
| SDK Package  | stellar_flutter_sdk ^2.0.0             |

---

## Contributor Setup Guide

Follow these steps in order to get your local environment ready.

### Step 1 — Clone and install Flutter dependencies

```bash
git clone https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-.git
cd Echo-Mirror-Butler-
flutter pub get
```

### Step 2 — Configure environment variables

```bash
cp backend/.env.example backend/.env
```

Open `backend/.env` and fill in the Stellar testnet keypairs (see Step 3).

### Step 3 — Create testnet accounts via Stellar Laboratory

You need two accounts: an **issuer** and a **distributor**.

1. Open [Stellar Laboratory — Keypair Generator](https://laboratory.stellar.org/#account-creator?network=test)
2. Generate a keypair → copy `Public Key` and `Secret Key` → these are your **issuer** keys
3. Repeat for a second keypair → these are your **distributor** keys
4. Fund both accounts with free testnet XLM using Friendbot:
   ```bash
   curl "https://friendbot.stellar.org?addr=YOUR_ISSUER_PUBLIC_KEY"
   curl "https://friendbot.stellar.org?addr=YOUR_DISTRIBUTOR_PUBLIC_KEY"
   ```
5. Paste both key pairs into `backend/.env`:
   ```
   STELLAR_ISSUER_PUBLIC=G...
   STELLAR_ISSUER_SECRET=S...
   STELLAR_DISTRIBUTOR_PUBLIC=G...
   STELLAR_DISTRIBUTOR_SECRET=S...
   ```

### Step 4 — Set up the Serverpod backend

The app communicates with the Serverpod server for gifting and wallet logic. You need a separate server repo.

```bash
# Clone the server repo (separate repository)
git clone https://github.com/Echo-Mirror-Butler/echomirror_server.git
cd echomirror_server

# Start PostgreSQL and Redis via Docker
docker compose up -d

# Run the server
dart run bin/main.dart
```

The server runs on `http://localhost:8080` by default.
The Flutter app connects to this URL — configured in `lib/core/constants/api_constants.dart`.

> **Serverpod docs:** https://docs.serverpod.dev

### Step 5 — Run the Flutter app

```bash
cd Echo-Mirror-Butler-
flutter run
```

Make sure the Serverpod server is running first (Step 4), otherwise the app will show a connection error.

### Step 6 — Run tests

```bash
# Run all Flutter/Dart tests
flutter test

# Run static analysis (must pass with no errors)
flutter analyze

# Check formatting
dart format --set-exit-if-changed .
```

---

## Serverpod Integration with Stellar

The ECHO gift feature requires Stellar blockchain integration for real transactions. This section covers the server-side implementation.

### Implementation Files

**In echomirror_server repo:**
- `lib/src/endpoints/gift_endpoint.dart` — Main endpoint (see `backend/serverpod_implementation/gift_endpoint.dart` for reference implementation)
- Models:
  - `lib/src/models/user_wallet.spy.yaml` — Stores public wallet keys and ECHO balances
  - `lib/src/models/gift_transaction.spy.yaml` — Records all gift transactions with Stellar tx hashes

**In Echo-Mirror-Butler- repo (reference implementations):**
- `backend/serverpod_implementation/gift_endpoint.dart` — Source code for GiftEndpoint (copy to server repo)
- `backend/serverpod_implementation/stellar_service_integration.dart` — Stellar operations wrapper

### GiftEndpoint Methods

| Method | Description |
|---|---|
| `getEchoBalance()` | Returns user's ECHO balance from database |
| `sendGift(recipientUserId, amount, message)` | Submits Stellar payment if both wallets configured; updates DB balance |
| `getGiftHistory()` | Returns user's sent + received gift transactions |
| `awardEcho(userId, amount, reason)` | Server-side ECHO award for participation |

### Integration Flow

When user sends a gift:

```
1. Lookup sender and recipient UserWallet records
2. Validate sender has sufficient ECHO balance
3. If both have Stellar public keys:
   ├─ Retrieve sender's secret key securely (from env/secrets manager)
   ├─ Call StellarService.sendEcho()
   ├─ Store returned transaction hash in GiftTransaction.stellarTxHash
4. If Stellar unavailable → fallback to DB-only transfer
5. Update both wallets' ECHO balances
6. Return GiftTransaction with stellarTxHash (or null)
```

When new wallet is created:

```
1. Call StellarService.createWallet()
   ├─ Generate Stellar keypair
   ├─ Fund via Friendbot (testnet)
2. Call StellarService.establishTrustline()
   ├─ Sign with user's secret key
   ├─ Enable ECHO asset holding
3. Store PUBLIC key in UserWallet.stellarPublicKey
4. ⚠️  NEVER store secret key in database
5. Initialize balance with welcome bonus (10 ECHO)
```

### After Endpoint Changes

Always regenerate Serverpod client:

```bash
cd echomirror_server
serverpod generate
```

The client and server models auto-sync.

---

## Stellar Service API

Available in `backend/serverpod_implementation/stellar_service_integration.dart`:

| Method | Description |
|---|---|
| `createWallet()` | Generates new Stellar keypair and funds via Friendbot |
| `establishTrustline(userSecret)` | Creates trustline for ECHO asset from user wallet |
| `sendEcho({senderSecret, recipientPublic, amount, memo})` | Submits ECHO payment; returns tx hash |
| `getEchoBalance(publicKey)` | Queries Horizon for user's ECHO balance |

---

## Architecture: Stellar Integration

The gift feature uses real Stellar testnet transactions with graceful fallback to database-only:

```
┌─────────────────────────────────────┐
│      Flutter Client App             │
│  GiftScreen → GiftRepository        │
│       ↓ sendGift()                  │
└────────────┬────────────────────────┘
             │ HTTP (Serverpod client)
             ↓
┌─────────────────────────────────────────────────────────────┐
│          Serverpod Backend Server                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ GiftEndpoint                                         │   │
│  │  sendGift()                                          │   │
│  │  ├─ Lookup sender wallet                            │   │
│  │  ├─ Lookup recipient wallet                         │   │
│  │  ├─ Validate balance                                │   │
│  │  ├─ Has Stellar keys?                               │   │
│  │  │  ├─ YES: Call StellarService.sendEcho()         │   │
│  │  │  └─ NO: Skip to DB update                        │   │
│  │  ├─ Update DB balances                              │   │
│  │  └─ Store GiftTransaction with tx hash              │   │
│  └──────────────────────────────────────────────────────┘   │
│         ↓                              ↓                     │
│  ┌─────────────────────┐  ┌───────────────────────────────┐ │
│  │ StellarService      │  │    PostgreSQL Database        │ │
│  │ - createWallet()    │  │ - user_wallet table           │ │
│  │ - establish         │  │ - gift_transaction table      │ │
│  │   Trustline()       │  │ - Balances & tx hashes        │ │
│  │ - sendEcho()        │  │                               │ │
│  │ - getBalance()      │  └───────────────────────────────┘ │
│  └────────────┬────────┘                                     │
└───────────────┼──────────────────────────────────────────────┘
                │ HTTPS (Stellar SDK)
                ↓
      ┌════════════════════════════════════════════┐
      │  Stellar Testnet                           │
      │  - Horizon API (horizon-testnet.stellar.org)
      │  - Account ledger                          │
      │  - Transaction broadcast                   │
      └════════════════════════════════════════════┘
```

**Flow highlights:**
- Real Stellar transactions when both users have configured wallets
- Database fallback if Stellar is unavailable
- Transaction hashes stored for verification
- Secret keys retrieved securely (never from database)

---

## Environment Configuration

### Stellar Testnet Setup

Set these environment variables before running your Serverpod backend:

```bash
# Issuer account (holds and issues ECHO token)
export STELLAR_ISSUER_PUBLIC=GB...   # 56-char public key
export STELLAR_ISSUER_SECRET=SB...   # Secure key — never commit!

# Optional: Distributor account (for issuing ECHO to users)
export STELLAR_DISTRIBUTOR_PUBLIC=GA...
export STELLAR_DISTRIBUTOR_SECRET=SA...
```

**To generate keypairs:**
1. Visit [Stellar Laboratory](https://laboratory.stellar.org/#account-creator?network=test)
2. Click "Generate Keypair"
3. Fund both accounts via Friendbot:
   ```bash
   curl "https://friendbot.stellar.org?addr=GB..."
   curl "https://friendbot.stellar.org?addr=GA..."
   ```

**For production:** Use a secrets manager (AWS Secrets Manager, HashiCorp Vault) instead of environment variables.

---

## Security Best Practices

### 🚨 Secret Key Management

**CRITICAL: Never store Stellar secret keys in the database.** Instead:

```dart
// ❌ WRONG
const dbSecret = userWallet.stellarSecret;  // This is a security breach!

// ✅ RIGHT — Store public key only
const publicKey = userWallet.stellarPublicKey;  // Safe to store
```

Retrieve secret keys from secure sources:

**Development (testnet only):**
```dart
final secret = const String.fromEnvironment('STELLAR_SENDER_SECRET');
```

**Production:**
```dart
// AWS Secrets Manager
final secret = await secretsManager.getSecret('stellar/sender-secret');

// HashiCorp Vault
final secret = await vault.read('secret/data/stellar/sender');

// Or key derivation
final secret = deriveSecretFromMasterKey(userId);
```

### 🔒 Endpoint Security

Add authentication to all gift endpoint calls:

```dart
class GiftEndpoint extends Endpoint {
  Future<GiftTransaction?> sendGift(Session session, ...) async {
    if (session.userId == null) {
      throw Exception('Not authenticated');
    }
    // Continue...
  }
}
```

### 📊 Logging & Monitoring

Log gift transactions for accountability:

```dart
logging.info('[GiftEndpoint] Gift: $amount ECHO from $sender to $recipient');
logging.warning('[GiftEndpoint] Stellar tx failed: $error');
logging.error('[GiftEndpoint] Critical error: balance mismatch');

// ⚠️  NEVER log secret keys!
// ❌ logging.info('Secret: $secret');  // SECURITY BREACH!
```

Monitor for:
- Failed Stellar transactions
- Repeated failed wallet creation
- Unusual balance changes
- Rate limit violations

---

## Rules for Contributors

- **Never commit real secret keys** — `.env` is gitignored
- Use **testnet only** during development — never mainnet
- All PRs must pass `flutter analyze` and `dart format` (enforced by CI)
- Reference this README when you are unsure about setup
- For Stellar concepts, see: [Stellar Developer Docs](https://developers.stellar.org/docs)
- For Serverpod concepts, see: [Serverpod Docs](https://docs.serverpod.dev)
