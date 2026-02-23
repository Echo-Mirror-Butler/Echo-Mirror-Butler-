# Stellar Integration Implementation — Quick Reference

## Files Created

All files are located in: `backend/serverpod_implementation/`

| File | Purpose |
|------|---------|
| `gift_endpoint.dart` | Main GiftEndpoint with full Stellar integration |
| `stellar_service_integration.dart` | Stellar SDK wrapper for Serverpod context |
| `user_wallet.spy.yaml` | Serverpod model for user wallets |
| `gift_transaction.spy.yaml` | Serverpod model for gift transactions |
| `STELLAR_INTEGRATION_GUIDE.md` | Complete setup and implementation guide |
| `ENV_CONFIG_GUIDE.md` | Environment variable configuration |
| `SECRETS_MANAGEMENT.md` | Secure secrets handling patterns |

## Implementation Steps in Your echomirror_server

### 1. Copy Core Files

```bash
# From Echo-Mirror-Butler-/backend/serverpod_implementation/

# Copy endpoint
cp gift_endpoint.dart ../echomirror_server/lib/src/endpoints/

# Copy Stellar service
cp stellar_service_integration.dart ../echomirror_server/lib/src/services/
```

### 2. Add Models

Create in your Serverpod server:

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

### 3. Add Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  stellar_flutter_sdk: ^2.0.0
  http: ^1.0.0
```

### 4. Configure Environment

Create `server.env`:

```bash
# Get these from Stellar Laboratory (testnet)
STELLAR_ISSUER_PUBLIC=GB...
STELLAR_ISSUER_SECRET=SB...
```

### 5. Generate Serverpod Code

```bash
cd echomirror_server
serverpod generate
```

### 6. Start Server

```bash
dart run bin/main.dart
```

### 7. Rebuild Flutter Client

```bash
cd Echo-Mirror-Butler-
flutter pub get
flutter run
```

## Key Implementation Details

### sendGift() Flow

```dart
Future<GiftTransaction?> sendGift(
  Session session,
  int recipientUserId,
  double amount,
  String? message,
) async {
  // 1. ✅ Look up wallets
  final senderWallet = await _getOrCreateWallet(session, senderId);
  final recipientWallet = await _getOrCreateWallet(session, recipientUserId);

  // 2. ✅ Validate balance
  if (senderWallet.echoBalance < amount) throw Exception('Insufficient balance');

  // 3. ✅ Call Stellar if both have keys
  String? stellarTxHash;
  if (senderWallet.stellarPublicKey != null && recipientWallet.stellarPublicKey != null) {
    // Get secret securely, submit transaction
    final secret = await _getSenderSecretKey(session, senderId);
    stellarTxHash = await StellarServiceIntegration.sendEcho(
      senderSecret: secret,
      recipientPublicKey: recipientWallet.stellarPublicKey,
      amount: amount,
      memo: message,
    );
  }

  // 4. ✅ Update DB and store hash
  senderWallet.echoBalance -= amount;
  await senderWallet.update(session);

  recipientWallet.echoBalance += amount;
  await recipientWallet.update(session);

  final transaction = GiftTransaction(
    senderUserId: senderId,
    recipientUserId: recipientUserId,
    echoAmount: amount,
    status: 'completed',
    message: message,
    stellarTxHash: stellarTxHash,
    createdAt: DateTime.now(),
  );

  await transaction.insert(session);
  return transaction;
}
```

### _getOrCreateWallet() Flow

```dart
Future<UserWallet> _getOrCreateWallet(Session session, int userId) async {
  var wallet = await UserWallet.db.findFirstWhere(session, ...);
  if (wallet != null) return wallet;

  // 1. ✅ Call StellarService.createWallet()
  final keypair = await StellarServiceIntegration.createWallet();

  // 2. ✅ Call StellarService.establishTrustline()
  await StellarServiceIntegration.establishTrustline(keypair.secretSeed);

  // 3. ✅ Store PUBLIC key only (never secret key!)
  wallet = UserWallet(
    userId: userId,
    echoBalance: 10.0,  // Welcome bonus
    stellarPublicKey: keypair.accountId,  // ← Only public key
    createdAt: DateTime.now(),
  );

  await wallet.insert(session);
  return wallet;
}
```

## Stellar Testnet Setup

### Get Keypairs

1. Visit: https://laboratory.stellar.org/#account-creator?network=test
2. Generate keypair → Copy public + secret
3. Generate 2nd keypair (for distributor)

### Fund Accounts

```bash
curl "https://friendbot.stellar.org?addr=GBXXXXXXX"
curl "https://friendbot.stellar.org?addr=GAXXXXXXX"
```

### Add to Environment

```bash
export STELLAR_ISSUER_PUBLIC=GB...
export STELLAR_ISSUER_SECRET=SB...
```

## Testing Flow

### 1. Create Two Test Users (in DB)

```sql
INSERT INTO user_wallet (user_id, echo_balance, stellar_public_key, created_at)
VALUES 
  (1, 10.0, NULL, NOW()),
  (2, 10.0, NULL, NOW());
```

### 2. Trigger Wallet Creation

Make a call to `getEchoBalance()` as user 1 — this invokes `_getOrCreateWallet()`:

```dart
final balance = await endpoint.getEchoBalance(session);
// Behind the scenes: database updated with Stellar public keys
```

### 3. Send Gift

```dart
final tx = await endpoint.sendGift(
  session,
  recipientUserId: 2,
  amount: 5.0,
  message: 'Great post!',
);

print('Tx hash: ${tx.stellarTxHash}');  // ← Real Stellar transaction!
```

### 4. Verify in Database

```sql
SELECT * FROM user_wallet WHERE user_id IN (1, 2);
-- Should show Stellar public keys and updated balances

SELECT * FROM gift_transaction WHERE sender_user_id = 1;
-- Should show stellarTxHash is NOT NULL
```

## Security Checklist

- [ ] Never store Stellar secret keys in database
- [ ] Use environment variables/secrets manager for secret retrieval
- [ ] Implement audit logging for secret access
- [ ] Use HTTPS for all Stellar API communication
- [ ] Rotate secret keys annually
- [ ] Implement rate limiting on gift endpoint
- [ ] Add authentication checks in endpoint
- [ ] Test failure scenarios (invalid recipient, insufficient balance)
- [ ] Monitor for unusual transaction patterns
- [ ] Set up alerts for failed Stellar transactions

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| "STELLAR_ISSUER_PUBLIC not set" | Missing env var | `export STELLAR_ISSUER_PUBLIC=GB...` |
| "Friendbot funding failed" | Account already funded / bad key | Check key is valid 56-char string |
| "Trustline failed" | Missing XLM balance | Ensure 2+ XLM in account |
| "Send transaction failed" | Low fee / invalid recipient | Check recipient has trustline |
| Transaction succeeds but no hash | Stellar service issue | Check Horizon connectivity |

## Files to Review

1. **GiftEndpoint**: [gift_endpoint.dart](gift_endpoint.dart)
   - Shows full integration with error handling
   - Demonstrates graceful fallback to DB-only

2. **Models**: [user_wallet.spy.yaml](user_wallet.spy.yaml), [gift_transaction.spy.yaml](gift_transaction.spy.yaml)
   - Define database schema
   - Include `stellarPublicKey` and `stellarTxHash` fields

3. **Secrets Guide**: [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md)
   - 7 patterns from simple to enterprise-grade
   - Production recommendations

4. **Setup Guide**: [STELLAR_INTEGRATION_GUIDE.md](STELLAR_INTEGRATION_GUIDE.md)
   - Full architecture and flow diagrams
   - Troubleshooting and testing

## Next Steps

1. Clone/create echomirror_server Serverpod project
2. Copy files to appropriate locations
3. Run `serverpod generate`
4. Set environment variables
5. Start server and test
6. Deploy with proper secrets management

---

For detailed setup: See [STELLAR_INTEGRATION_GUIDE.md](STELLAR_INTEGRATION_GUIDE.md)  
For secrets: See [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md)  
For config: See [ENV_CONFIG_GUIDE.md](ENV_CONFIG_GUIDE.md)
