# EchoMirror Backend — Stellar Integration

This folder contains:
1. **`server/`** — Node.js + Express REST API for Stellar wallet management and ECHO gifting (issue #103)
2. **`stellar/`** — Dart Stellar service used by the Flutter client (reference implementation)

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
├── server/                        # Node.js Express API server (issue #103)
│   ├── src/
│   │   ├── index.ts               # Express entry point (port 3000)
│   │   ├── routes/
│   │   │   └── stellar.ts         # POST /wallet/create, GET /wallet/balance,
│   │   │                          # POST /gift, GET /transactions
│   │   ├── middleware/
│   │   │   ├── auth.ts            # Supabase JWT verification
│   │   │   └── errorHandler.ts    # Global error handler
│   │   └── services/
│   │       ├── supabase.ts        # Supabase admin client (service role)
│   │       └── stellar.ts         # Stellar SDK — wallet, trustline, payments
│   ├── docs/
│   │   └── stellar-api.json       # Postman/Bruno collection
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
├── stellar/
│   ├── stellar_config.dart        # Network config, asset code, Horizon URL
│   ├── echo_token.dart            # ECHO asset definition and reward constants
│   └── stellar_service.dart       # Dart Stellar service (Flutter client)
└── .env.example                   # Stellar keypair environment template
```

---

## Node.js Server (issue #103)

### Setup

```bash
cd backend/server
npm install
cp .env.example .env   # fill in all values
npm run dev            # starts on http://localhost:3000
```

### API Routes

All routes (except `GET /health`) require a valid Supabase JWT:
```
Authorization: Bearer <supabase_jwt>
```

| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/health` | Server health check |
| `POST` | `/stellar/wallet/create` | Create + fund testnet wallet, store public key |
| `GET` | `/stellar/wallet/balance` | Get XLM and ECHO balances |
| `POST` | `/stellar/gift` | Send ECHO to another user |
| `GET` | `/stellar/transactions` | Paginated gift history |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `PORT` | Server port (default `3000`) |
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (bypasses RLS — keep secret) |
| `JWT_SECRET` | Supabase JWT secret (from project settings) |
| `STELLAR_ISSUER_PUBLIC` | ECHO token issuer public key |
| `STELLAR_ISSUER_SECRET` | ECHO token issuer secret key |
| `STELLAR_HORIZON_URL` | Horizon endpoint (default: testnet) |
| `STELLAR_NETWORK_PASSPHRASE` | Stellar network passphrase |
| `STELLAR_ASSET_CODE` | Token code (default: `ECHO`) |

### Testing with Postman/Bruno

Import `backend/server/docs/stellar-api.json` into Postman or Bruno.
Set the `base_url` and `jwt_token` collection variables before running requests.

---

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
git clone https://github.com/akintewe/echomirror-server .server
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
