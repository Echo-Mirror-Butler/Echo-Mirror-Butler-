# EchoMirror Backend — Stellar Integration

This folder contains the Stellar blockchain integration for the **ECHO token**, the in-app currency used in the Global Mirror gifting feature.

## What is ECHO?

ECHO is a custom Stellar asset on the testnet. Users earn ECHO by participating in the Global Mirror:
- Sharing a mood pin → **+2 ECHO**
- Posting a video → **+5 ECHO**
- Receiving a comment on your pin → **+1 ECHO**
- New user welcome bonus → **+10 ECHO**

Users can gift ECHO to others to show appreciation.

## Setup (Testnet)

### 1. Install dependencies
The Stellar Flutter SDK is already listed in `pubspec.yaml`:
```yaml
stellar_flutter_sdk: ^2.0.0
```

### 2. Configure environment
```bash
cp backend/.env.example backend/.env
# Fill in your testnet keypairs
```

### 3. Create the issuer account (one-time)
Use [Stellar Laboratory](https://laboratory.stellar.org/#account-creator?network=test) to:
1. Generate a keypair for the **issuer**
2. Fund it with Friendbot (free testnet XLM)
3. Copy the public/secret keys to your `.env`

### 4. Create the ECHO asset
The issuer account establishes ECHO by sending it to any account with a trustline.
`StellarService` handles this automatically when users set up their wallets.

## File Structure

```
backend/
├── stellar/
│   ├── stellar_config.dart    # Network config, asset code, horizon URL
│   ├── echo_token.dart        # ECHO asset definition and reward constants
│   └── stellar_service.dart   # Wallet creation, trustlines, payments
└── .env.example               # Environment variable template
```

## Network Details

| Setting | Value |
|---------|-------|
| Network | Testnet |
| Horizon URL | https://horizon-testnet.stellar.org |
| Asset Code | ECHO |
| Friendbot | https://friendbot.stellar.org |

## For Contributors

- Never commit real secret keys
- Use testnet only during development
- Run `flutter test` to verify Stellar service logic
- See [Stellar Developer Docs](https://developers.stellar.org/docs) for full reference
