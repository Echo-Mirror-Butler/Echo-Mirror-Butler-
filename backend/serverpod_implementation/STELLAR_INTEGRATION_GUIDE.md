# Stellar Integration in Serverpod GiftEndpoint — Implementation Guide

This document explains how to connect **StellarService** to the **GiftEndpoint** in the Serverpod backend for real Stellar blockchain transactions.

## Quick Summary

When a user sends an ECHO gift:
1. ✅ Look up sender and recipient wallet records
2. ✅ Validate sender has sufficient balance
3. ✅ Check if both have Stellar public keys
4. ✅ Call `StellarService.sendEcho()` to submit to Stellar testnet
5. ✅ Store the transaction hash in the database
6. ✅ Fall back gracefully to DB-only if Stellar is unavailable
7. ✅ Return transaction with hash to client

When creating a new wallet:
1. ✅ Call `StellarService.createWallet()` to generate keypair + fund via Friendbot
2. ✅ Call `StellarService.establishTrustline()` to enable ECHO holding
3. ✅ Store **ONLY** the public key in the database
4. ✅ Store the secret key securely (environment/secrets manager, never DB)

---

## Setup Steps

### Step 1: Create the Serverpod Server Repository

If you don't have echomirror_server yet:

```bash
cd /Users/mac/Desktop/Programming

# Create new Serverpod project
serverpod create-app echo_server
cd echo_server
```

### Step 2: Copy Model Definitions

In your server repo, create the models:

**`lib/src/models/user_wallet.spy.yaml`**
```yaml
class: UserWallet
table: user_wallet
fields:
  id: int, autoIncrement
  userId: int
  echoBalance: double
  stellarPublicKey: String?, db
  createdAt: DateTime
  updatedAt: DateTime?
```

**`lib/src/models/gift_transaction.spy.yaml`**
```yaml
class: GiftTransaction
table: gift_transaction
fields:
  id: int, autoIncrement
  senderUserId: int
  recipientUserId: int
  echoAmount: double
  status: String
  message: String?, db
  stellarTxHash: String?, db
  createdAt: DateTime
  updatedAt: DateTime?
```

### Step 3: Add Dependencies

In your server's `pubspec.yaml`, add:

```yaml
dependencies:
  stellar_flutter_sdk: ^2.0.0
  http: ^1.0.0
```

Then:
```bash
dart pub get
```

### Step 4: Add Stellar Configuration & Service

Copy the following files from `backend/serverpod_implementation/` to your server repo:

- `lib/src/stellar_service_integration.dart` — The Stellar SDK wrapper
- Copy it to `lib/src/services/` or a location in your server structure

### Step 5: Create the GiftEndpoint

Create `lib/src/endpoints/gift_endpoint.dart` with the code from `backend/serverpod_implementation/gift_endpoint.dart`.

**Key changes for your setup:**
- Import your custom `GiftTransaction` and `UserWallet` models
- Adjust imports to match your project structure
- Update the `_getSenderSecretKey()` method to use your secrets infrastructure

### Step 6: Environment Configuration

Create `server.env` (or update your `.env`):

```
STELLAR_ISSUER_PUBLIC=G...  # Your testnet issuer public key
STELLAR_ISSUER_SECRET=S...  # (optional) Used for issuing ECHO
```

See `backend/README.md` for how to generate these via Stellar Laboratory.

### Step 7: Generate Serverpod Endpoints

```bash
cd your-server-repo
serverpod generate
```

This generates client code that the Flutter app can call.

### Step 8: Rebuild the Client

Back in the Flutter app:

```bash
cd Echo-Mirror-Butler-
flutter pub get
flutter run
```

---

## Code Flow Breakdown

### When User Sends a Gift

```
Client (Flutter)
    ↓ calls sendGift(recipientId, amount, message)
    ↓
Serverpod GiftEndpoint
    ├─ Lookup sender wallet
    ├─ Lookup recipient wallet
    ├─ Validate balance
    ├─ Check if both have Stellar keys
    │
    ├─ (YES) → StellarService.sendEcho()
    │   ├─ Retrieve sender's secret key securely
    │   ├─ Build Stellar payment transaction
    │   ├─ Sign & submit to Horizon
    │   └─ Get transaction hash
    │
    ├─ (NO) → Skip Stellar, continue DB-only
    │
    ├─ Update sender balance (DB)
    ├─ Update recipient balance (DB)
    ├─ Create GiftTransaction record
    │   └─ Store stellarTxHash if available
    │
    └─ Return GiftTransaction to client
            ↓
        Client displays success ✓
```

### When New User Signs Up

```
Client creates auth
    ↓
Server creates user record
    ↓
GiftEndpoint._getOrCreateWallet() triggered (lazy)
    ├─ StellarService.createWallet()
    │   ├─ Generate keypair
    │   └─ Fund via Friendbot
    │   
    ├─ StellarService.establishTrustline()
    │   ├─ Sign with user's secret
    │   └─ Submit trust tx to Horizon
    │
    ├─ Store in database:
    │   ├─ PUBLIC key → UserWallet.stellarPublicKey
    │   └─ SECRET key → Secrets manager (NOT database!)
    │
    └─ Initialize balance: 10 ECHO (welcome bonus)
```

---

## Security Best Practices

### 🔐 Secret Key Management

**NEVER store Stellar secret keys in the database.** Instead:

1. **Hard-code in config (test only):**
   ```dart
   static const String testSecretKey = 'S...';
   ```

2. **Environment variables (production):**
   ```bash
   export STELLAR_SENDER_SECRET_KEY=S...
   ```
   Then in code:
   ```dart
   final secret = const String.fromEnvironment('STELLAR_SENDER_SECRET_KEY');
   ```

3. **AWS Secrets Manager (recommended):**
   ```dart
   final secret = await _secretsService.getSecret('stellar/sender/secret');
   ```

4. **HashiCorp Vault (enterprise):**
   ```dart
   final secret = await vaultClient.getSecret('stellar/sender');
   ```

5. **Key Derivation:**
   - Generate per-user secret from server master key + user ID
   - Never persist the secret; derive it on-demand

### 🔒 Database Design

```sql
-- UserWallet: Store PUBLIC key only
CREATE TABLE user_wallet (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  echo_balance DOUBLE NOT NULL DEFAULT 10.0,
  stellar_public_key VARCHAR(56),  -- ← PUBLIC key ONLY
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- GiftTransaction: Store transaction metadata
CREATE TABLE gift_transaction (
  id SERIAL PRIMARY KEY,
  sender_user_id INT NOT NULL,
  recipient_user_id INT NOT NULL,
  echo_amount DOUBLE NOT NULL,
  status VARCHAR(20),
  message TEXT,
  stellar_tx_hash VARCHAR(64),  -- ← Transaction hash for verification
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### 🛡️ Endpoint Access Control

Add authentication to the gift endpoint:

```dart
// In GiftEndpoint methods:
if (session.userId == null) {
  throw Exception('Not authenticated');
}

// Optional: Rate limiting
if (!await _checkRateLimit(session.userId)) {
  throw Exception('Too many requests');
}
```

### 📊 Logging & Monitoring

Log important events:

```dart
logging.info('[GiftEndpoint] Gift sent: $amount ECHO from $senderId to $recipientId');
logging.warning('[GiftEndpoint] Stellar tx failed, using DB-only fallback');
logging.error('[GiftEndpoint] Critical error: $e');
```

Monitor for:
- Failed Stellar transactions (but DB succeeded)
- Wallet creation timeouts
- Trustline failures
- Balance mismatches

---

## Troubleshooting

### Q: Stellar transactions fail but client doesn't see an error

**A:** Add comprehensive error handling:
```dart
try {
  stellarTxHash = await StellarService.sendEcho(...);
} catch (e) {
  logging.error('Stellar error: $e');
  // Gracefully continue with DB-only
}
```

### Q: User can't hold ECHO after wallet creation

**A:** Verify `establishTrustline()` succeeded. Check:
```
1. User has XLM balance (funded by Friendbot)
2. Issuer public key is correctly configured
3. Asset code matches ("ECHO")
4. Stellar testnet is online (check Horizon)
```

### Q: Secret key is being logged

**A:** Never log secrets:
```dart
// ❌ WRONG:
logging.info('Secret key: $secret');

// ✅ RIGHT:
logging.info('Wallet created for user $userId');
// logging has the secret, never output it!
```

### Q: "Environment variable 'STELLAR_ISSUER_PUBLIC' not found"

**A:** Set it before running the server:
```bash
export STELLAR_ISSUER_PUBLIC=G...
dart run bin/main.dart
```

Or use a `.env` file with a package like `dotenv`.

---

## Testing Workflow

### Test Scenario 1: Create Wallet

```bash
# Call endpoint to trigger wallet creation
curl http://localhost:8080/gift/getEchoBalance

# Verify in DB
SELECT * FROM user_wallet WHERE user_id = 1;
```

Expected: `stellar_public_key` is `G...`, `echo_balance` is 10.0

### Test Scenario 2: Send Gift

```dart
// In your test:
final result = await endpoint.sendGift(
  session,
  recipientUserId: 2,
  amount: 5.0,
  message: 'Great mood!',
);

expect(result.stellarTxHash, isNotNull); // Or null if Stellar unavailable
expect(result.status, 'completed');
```

### Test Scenario 3: Graceful Fallback

```dart
// Temporarily set issuer to empty to test DB-only mode
// (in code): issuerPublicKey = '';

final result = await endpoint.sendGift(...);
expect(result.stellarTxHash, isNull); // ← Falls back to DB-only
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Client App                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  gift_repository.dart                                   │   │
│  │  - sendGift(recipientId, amount, message)              │   │
│  │  - getEchoBalance()                                    │   │
│  │  - getGiftHistory()                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────────┘
                 │ HTTP REST (Serverpod client)
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Serverpod Backend Server                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  gift_endpoint.dart (GiftEndpoint)                      │   │
│  │  + sendGift()       ← Main entry point                  │   │
│  │  + getEchoBalance()                                     │   │
│  │  + getGiftHistory()                                     │   │
│  │  + awardEcho()                                          │   │
│  │  - _getOrCreateWallet()   ← Stellar wallet creation    │   │
│  │  - _getSenderSecretKey()  ← Secrets retrieval          │   │
│  └──────────────────────────────────────────────────────────┘   │
│          ↓                              ↓                       │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ stellar_service.dart │  │  Database (Postgres) │             │
│  │ - createWallet()     │  │  - user_wallet       │             │
│  │ - establishTrustline │  │  - gift_transaction  │             │
│  │ - sendEcho()         │  │  - Balances          │             │
│  │ - getEchoBalance()   │  │                      │             │
│  └──────────────────────┘  └──────────────────────┘             │
│          ↓                                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Stellar Flutter SDK (HTTP requests to Horizon)         │   │
│  │  - Build transactions                                   │   │
│  │  - Sign transactions                                    │   │
│  │  - Submit to Horizon API                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────────────┘
                 │ HTTPS
                 ↓
      ┌──────────────────────┐
      │  Stellar Testnet     │
      │  - Horizon API       │
      │  - Account data      │
      │  - Transaction ledger│
      └──────────────────────┘
```

---

## Next Steps

1. **Copy files** to your server repo:
   - `gift_endpoint.dart` → `lib/src/endpoints/gift_endpoint.dart`
   - `stellar_service_integration.dart` → `lib/src/services/stellar_service_integration.dart`

2. **Update models** in your Serverpod:
   - `user_wallet.spy.yaml`
   - `gift_transaction.spy.yaml`

3. **Configure secrets** in your infrastructure

4. **Run** `serverpod generate` to create client code

5. **Test** the full flow end-to-end

6. **Deploy** to production with proper secrets management

---

## References

- **Serverpod Docs:** https://docs.serverpod.dev
- **Stellar Developer Docs:** https://developers.stellar.org/docs
- **Stellar Flutter SDK:** https://pub.dev/packages/stellar_flutter_sdk
- **Horizon API Docs:** https://developers.stellar.org/api/
- **Best Practices:** See `../README.md` in the backend folder
