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

### Step 1 — Clone both repos and install Flutter dependencies

The app depends on the server client package via a local path (`.server/`).
You must clone the server repo into `.server/` inside the app repo before running `flutter pub get`.

```bash
git clone https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-.git
cd Echo-Mirror-Butler-
git clone https://github.com/Echo-Mirror-Butler/echomirror_server .server
flutter pub get
```

> **Note:** `.server/` is gitignored — it will never be committed.

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

## Serverpod Gift Endpoint

The gift feature lives in the server repo at:
```
lib/src/endpoints/gift_endpoint.dart
```

Methods:
| Method | Description |
|---|---|
| `getEchoBalance()` | Returns the current user's ECHO balance |
| `sendGift(recipientUserId, amount, message)` | Transfers ECHO from sender to recipient |
| `getGiftHistory()` | Returns the current user's gift transaction history |
| `awardEcho(userId, amount, reason)` | Server-side ECHO award (mood pins, videos, etc.) |

After modifying any Serverpod endpoint or YAML model, regenerate the client:
```bash
cd echomirror_server
serverpod generate
```

---

## Stellar Service API

`backend/stellar/stellar_service.dart` exposes:

| Method | Description |
|---|---|
| `createWallet()` | Generates a new Stellar keypair and funds via Friendbot |
| `establishTrustline(secretKey)` | Creates a trustline for the ECHO asset |
| `sendEcho(senderSecret, recipientPublic, amount)` | Sends ECHO between wallets |
| `getEchoBalance(publicKey)` | Fetches ECHO balance from Horizon |

---

## Rules for Contributors

- **Never commit real secret keys** — `.env` is gitignored
- Use **testnet only** during development — never mainnet
- All PRs must pass `flutter analyze` and `dart format` (enforced by CI)
- Reference this README when you are unsure about setup
- For Stellar concepts, see: [Stellar Developer Docs](https://developers.stellar.org/docs)
- For Serverpod concepts, see: [Serverpod Docs](https://docs.serverpod.dev)
