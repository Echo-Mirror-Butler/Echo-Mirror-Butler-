# EchoMirror Server

Serverpod backend for the EchoMirror Flutter app.

## Prerequisites

- **Flutter SDK** (3.10.0+) with Dart
- **Docker Desktop** (for PostgreSQL and Redis)
- **Serverpod CLI** (optional, for code generation)

## Quick Start

### 1. Start Docker containers

```bash
cd echomirror_server
docker compose up -d
```

This starts:
- PostgreSQL on port 5432
- Redis on port 6379

### 2. Initialize the database

Connect to PostgreSQL and run the migration:

```bash
# Using psql (if installed)
psql -h localhost -U postgres -d echomirror -f migrations/20240101000000/definition.sql

# Or using Docker
docker exec -i echomirror_postgres psql -U postgres -d echomirror < migrations/20240101000000/definition.sql
```

Password: `echomirror_dev_password`

### 3. Install dependencies

```bash
dart pub get
```

### 4. Run the server

```bash
dart run bin/main.dart
```

The server runs on `http://localhost:8080`.

## Endpoints

### Gift Endpoint (`/gift`)

| Method | Description |
|--------|-------------|
| `getEchoBalance()` | Returns current user's ECHO balance |
| `sendGift(recipientUserId, amount, message)` | Send ECHO to another user |
| `getGiftHistory()` | Get gift transaction history |
| `awardEcho(userId, amount, reason)` | Award ECHO (server-side) |

### Global Endpoint (`/global`)

| Method | Description |
|--------|-------------|
| `streamMoodPins()` | Stream mood pins in real-time |
| `addMoodPin(sentiment, lat, lon)` | Add a mood pin |
| `uploadVideo(videoData, moodTag)` | Upload video post |
| `uploadImage(imageData, moodTag)` | Upload image post |
| `getVideoFeed(offset, limit)` | Get video feed |
| `addComment(moodPinId, text)` | Add comment to pin |
| `getCommentsForPin(moodPinId)` | Get comments for pin |

### Password Reset Endpoint (`/passwordReset`)

| Method | Description |
|--------|-------------|
| `requestPasswordReset(email)` | Request password reset |
| `resetPassword(email, token, newPassword)` | Reset password |
| `changePassword(currentPassword, newPassword)` | Change password |

## ECHO Token Economy

New users receive **10 ECHO** as a welcome bonus.

Earning ECHO:
- Share a mood pin: **+2 ECHO**
- Post a video: **+5 ECHO**
- Receive a comment: **+1 ECHO**

## Development

### Regenerate code (if you modify models)

```bash
serverpod generate
```

### Run tests

```bash
dart test
```

## Configuration

- `config/development.yaml` - Server configuration
- `config/passwords.yaml` - Database passwords
- `docker-compose.yaml` - Docker services

## Troubleshooting

### Connection refused

Make sure Docker containers are running:
```bash
docker compose ps
```

### Database not found

Create the database:
```bash
docker exec -it echomirror_postgres psql -U postgres -c "CREATE DATABASE echomirror;"
```

Then run the migration SQL.
