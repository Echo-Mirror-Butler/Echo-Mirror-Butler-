# Stellar Integration Environment Configuration

This file shows how to set up environment variables for Stellar integration
in the Serverpod backend.

## For Development (Testnet Only)

### 1. Generate Stellar Testnet Keypairs

Visit [Stellar Laboratory](https://laboratory.stellar.org/#account-creator?network=test):

1. Click "Generate Keypair"
2. Copy the **Public Key** and **Secret Key**
3. Find a second keypair (distributor) for issuing ECHO

### 2. Fund Both Accounts via Friendbot

For each public key, run:

```bash
curl "https://friendbot.stellar.org?addr=GBXXXXXXXXXXX"
```

Wait for success response (~10 ECHO's worth of XLM).

### 3. Create `.env` or `server.env`

In your Serverpod server root or as environment variables:

```bash
# Stellar Testnet Configuration
export STELLAR_ISSUER_PUBLIC=GBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export STELLAR_ISSUER_SECRET=SBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export STELLAR_DISTRIBUTOR_PUBLIC=GAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export STELLAR_DISTRIBUTOR_SECRET=SAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Optional: Sender account for issuing ECHO to users
# (Can be same as distributor)
export STELLAR_SENDER_SECRET=SBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 4. Start Server with Environment

#### Option A: Export before running

```bash
# macOS / Linux
export STELLAR_ISSUER_PUBLIC=GB...
export STELLAR_ISSUER_SECRET=SB...
dart run bin/main.dart

# Windows (PowerShell)
$env:STELLAR_ISSUER_PUBLIC="GB..."
dart run bin/main.dart
```

#### Option B: Use .env with dotenv package

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  dotenv: ^1.0.0
```

Create `server.env`:

```
STELLAR_ISSUER_PUBLIC=GB...
STELLAR_ISSUER_SECRET=SB...
```

In `bin/main.dart`:

```dart
import 'package:dotenv/dotenv.dart' as dotenv;

void main() async {
  await dotenv.load(fileName: 'server.env');
  
  // Now environment variables are available
  runApp(YourServerApp());
}
```

#### Option C: Use Serverpod config system

In `config/server.yaml`:

```yaml
stellar:
  issuerPublicKey: ${STELLAR_ISSUER_PUBLIC}
  issuerSecretKey: ${STELLAR_ISSUER_SECRET}
```

Then access in code:

```dart
import 'package:echomirror_server/server.dart';

// In GiftEndpoint or StellarService:
final config = await getCustomConfig() as ServerConfig;
final issuerPublic = config.stellar.issuerPublicKey;
```

## For Docker/Production

### Environment Variables in Docker

In your `docker-compose.yml`:

```yaml
services:
  server:
    image: my-server:latest
    environment:
      - STELLAR_ISSUER_PUBLIC=${STELLAR_ISSUER_PUBLIC}
      - STELLAR_ISSUER_SECRET=${STELLAR_ISSUER_SECRET}
      - STELLAR_DISTRIBUTOR_PUBLIC=${STELLAR_DISTRIBUTOR_PUBLIC}
      - STELLAR_DISTRIBUTOR_SECRET=${STELLAR_DISTRIBUTOR_SECRET}
    networks:
      - default
```

### With Secrets Manager (AWS)

```dart
import 'package:aws_secrets_manager/aws_secrets_manager.dart';

Future<String> getStellarSecret(String name) async {
  final client = SecretsManagerClient();
  final secret = await client.getSecretValue(secretId: 'stellar/$name');
  return secret.secretString;
}

// Usage in code:
final issuerSecret = await getStellarSecret('issuer_secret');
```

### With HashiCorp Vault (Enterprise)

```dart
import 'package:vault/vault.dart';

Future<Map<String, String>> getStellarSecrets() async {
  final vault = VaultClient(baseUrl: Uri.parse('https://vault.example.com'));
  final secret = await vault.kv.read('secret/data/stellar');
  return {
    'issuerPublic': secret['STELLAR_ISSUER_PUBLIC'],
    'issuerSecret': secret['STELLAR_ISSUER_SECRET'],
  };
}
```

## Testing Configuration

For unit/integration tests, you may want to mock:

```dart
// In test files:
import 'package:mockito/mockito.dart';

void main() {
  group('GiftEndpoint Stellar Integration', () {
    late GiftEndpoint endpoint;
    
    setUp(() {
      // Mock Stellar service for tests
      final mockStellarService = MockStellarService();
      when(mockStellarService.sendEcho(...)).thenAnswer(
        (_) async => 'mock_tx_hash_12345',
      );
      
      endpoint = GiftEndpoint(stellarService: mockStellarService);
    });

    test('sendGift stores transaction hash', () async {
      final tx = await endpoint.sendGift(session, 2, 5.0, 'Test');
      expect(tx.stellarTxHash, 'mock_tx_hash_12345');
    });
  });
}
```

## Verifying Configuration

### Check environment variables are loaded

```dart
void main() {
  final issuer = const String.fromEnvironment('STELLAR_ISSUER_PUBLIC');
  if (issuer.isEmpty) {
    print('❌ STELLAR_ISSUER_PUBLIC not set!');
  } else {
    print('✅ STELLAR_ISSUER_PUBLIC: ${issuer.substring(0, 10)}...');
  }
}
```

### Verify testnet connectivity

```dart
Future<void> verifyTestnetConnection() async {
  final sdk = StellarSDK('https://horizon-testnet.stellar.org');
  
  try {
    final assets = await sdk.assets.limit(1).execute();
    print('✅ Connected to Stellar testnet');
  } catch (e) {
    print('❌ Cannot connect to Stellar testnet: $e');
  }
}
```

### Check account funding

```dart
Future<void> checkAccountFunding(String publicKey) async {
  final sdk = StellarSDK('https://horizon-testnet.stellar.org');
  final account = await sdk.accounts.account(publicKey);
  
  for (final balance in account.balances) {
    print('${balance.assetCode}: ${balance.balance}');
  }
}
```

## Production Deployment Checklist

- [ ] Use secrets manager (AWS, Vault, etc.) — NOT environment variables
- [ ] Rotate secret keys annually
- [ ] Never commit real keys to git (`.env` should be in `.gitignore`)
- [ ] Use Stellar **mainnet** (not testnet) if deploying to production
- [ ] Monitor failed Stellar transactions
- [ ] Set up alerts for balance anomalies
- [ ] Test full gift flow including failure scenarios
- [ ] Have database backups before going live
- [ ] Document your secrets infrastructure
- [ ] Implement rate limiting for gift endpoint
- [ ] Add authentication/authorization checks
- [ ] Run static analysis and security scans
- [ ] Perform load testing with Stellar transactions

## Troubleshooting

### "STELLAR_ISSUER_PUBLIC environment variable not set"

**Solution:**
```bash
export STELLAR_ISSUER_PUBLIC=GB...
dart run bin/main.dart
```

### "Friendbot funding failed"

**Cause:** Public key already funded or invalid
**Solution:**
```bash
# Check if account exists
curl -H "Accept: application/json" \
  "https://horizon-testnet.stellar.org/accounts/GB..."
```

### "Trustline establishment failed"

**Cause:** 
- Issuer public key is empty
- Account doesn't have XLM for transaction fee
- Asset code doesn't match

**Solution:**
1. Verify `STELLAR_ISSUER_PUBLIC` is set
2. Check account has at least 2 XLM balance
3. Confirm asset code is "ECHO"

### "Transaction submission failed"

**Cause:** Low XLM balance, invalid operation, or network issue
**Solution:**
1. Check sender has minimum XLM for fee
2. Verify recipient has trustline
3. Check Stellar testnet status

---

For more information, see `STELLAR_INTEGRATION_GUIDE.md`
