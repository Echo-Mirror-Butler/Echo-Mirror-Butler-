# EchoMirror Serverpod Server

Database migration setup for EchoMirror gifting feature with `user_wallets` and `gift_transactions` tables.

## 📋 Overview

This repository contains the Serverpod server configuration and database migrations for the EchoMirror application's gifting functionality. The setup includes PostgreSQL database tables for managing user ECHO token wallets and gift transactions.

## 🗄️ Database Schema

### user_wallets Table
Stores wallet information for each user:
- `userId` (int, unique) - User identifier
- `echoBalance` (double, default: 0.0) - Current ECHO token balance
- `stellarPublicKey` (varchar, nullable) - Stellar wallet public key
- `createdAt` (timestamp) - Wallet creation time
- `updatedAt` (timestamp) - Last update time (auto-updated)

### gift_transactions Table
Records ECHO token transfers between users:
- `senderUserId` (int) - Sender user identifier
- `recipientUserId` (int) - Recipient user identifier
- `echoAmount` (double) - Amount of ECHO tokens transferred
- `stellarTxHash` (varchar, nullable) - Stellar transaction hash
- `message` (varchar, nullable) - Optional gift message
- `createdAt` (timestamp) - Transaction creation time
- `status` (varchar, default: 'pending') - Transaction status

## 🚀 Quick Start

### Prerequisites
- Docker Desktop installed and running
- Dart SDK installed (comes with Flutter)
- Git for version control

### Setup Steps

1. **Start Database Services**
   ```bash
   cd echomirror_server_server
   docker compose up -d
   ```

2. **Wait for Database Initialization**
   ```bash
   # Monitor PostgreSQL startup
   docker compose logs -f postgres
   ```

3. **Apply Database Migrations**
   ```bash
   # Apply user_wallets table migration
   docker exec -i echomirror_postgres psql -U postgres -d echomirror < migrations/20240224000001_create_user_wallets.sql
   
   # Apply gift_transactions table migration
   docker exec -i echomirror_postgres psql -U postgres -d echomirror < migrations/20240224000002_create_gift_transactions.sql
   ```

4. **Verify Setup**
   ```bash
   # Check if tables exist
   docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\dt"
   
   # Verify table structures
   docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\d user_wallets"
   docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\d gift_transactions"
   ```

5. **Start Serverpod Server**
   ```bash
   dart run bin/main.dart
   ```

## 🔍 Verification & Health Checks

### Automated Verification
Run the PowerShell verification script:
```powershell
.\verify_setup.ps1
```

### Manual Verification Steps

#### 1. Docker Services Check
```bash
# Check if containers are running
docker ps --filter "name=echomirror_"

# Expected output:
# echomirror_postgres
# echomirror_redis
```

#### 2. Database Connection Test
```bash
# Test PostgreSQL connection
docker exec echomirror_postgres psql -U postgres -d echomirror -c "SELECT version();"

# Test Redis connection
docker exec echomirror_redis redis-cli ping
# Expected response: PONG
```

#### 3. Table Structure Verification
```bash
# Verify user_wallets table
docker exec echomirror_postgres psql -U postgres -d echomirror -c "
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'user_wallets' 
ORDER BY ordinal_position;"

# Verify gift_transactions table
docker exec echomirror_postgres psql -U postgres -d echomirror -c "
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'gift_transactions' 
ORDER BY ordinal_position;"
```

#### 4. Index Verification
```bash
# Check indexes on user_wallets
docker exec echomirror_postgres psql -U postgres -d echomirror -c "
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'user_wallets';"

# Check indexes on gift_transactions
docker exec echomirror_postgres psql -U postgres -d echomirror -c "
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'gift_transactions';"
```

#### 5. Trigger Verification
```bash
# Check if update trigger exists on user_wallets
docker exec echomirror_postgres psql -U postgres -d echomirror -c "
SELECT tgname, tgrelid::regclass, tgfoid::regproc 
FROM pg_trigger 
WHERE tgrelid = 'user_wallets'::regclass;"
```

## 📁 Project Structure

```
echomirror_server_server/
├── lib/src/
│   ├── user_wallet.spy.yaml          # Serverpod model for user wallets
│   └── gift_transaction.spy.yaml     # Serverpod model for gift transactions
├── migrations/
│   ├── 20240224000001_create_user_wallets.sql
│   └── 20240224000002_create_gift_transactions.sql
├── docker-compose.yml                # PostgreSQL and Redis services
├── pubspec.yaml                      # Dart package configuration
├── setup_database.md                 # Detailed setup instructions
├── verify_setup.ps1                  # Automated verification script
└── README.md                         # This file
```

## 🔧 Configuration

### Database Connection Details
- **Host**: localhost
- **Port**: 5432
- **Database**: echomirror
- **Username**: postgres
- **Password**: postgres

### Redis Connection Details
- **Host**: localhost
- **Port**: 6379

## 🐛 Troubleshooting

### Common Issues

#### Docker Issues
- **Problem**: `docker: command not found`
- **Solution**: Install Docker Desktop and restart terminal
- **Problem**: Containers fail to start
- **Solution**: Ensure Docker Desktop is running and has sufficient resources

#### Database Issues
- **Problem**: Connection refused
- **Solution**: Wait 30-60 seconds after `docker compose up -d` for PostgreSQL to initialize
- **Problem**: Migration fails
- **Solution**: Check SQL syntax and PostgreSQL logs with `docker compose logs postgres`

#### Permission Issues
- **Problem**: Permission denied on Docker commands
- **Solution**: Run terminal as Administrator or add user to docker group

### Health Check Commands

```bash
# Overall system health
docker compose ps
docker compose logs

# Database health
docker exec echomirror_postgres pg_isready -U postgres

# Redis health
docker exec echomirror_redis redis-cli ping

# Disk space check
docker system df
```

## 📝 Development Notes

### Migration Naming Convention
Migrations follow the timestamp format: `YYYYMMDDHHMMSS_description.sql`

### Serverpod Model Validation
Models are validated for:
- Correct YAML syntax
- Proper field types and constraints
- Appropriate indexes for performance

### Database Best Practices
- All tables have primary keys (`id SERIAL`)
- Timestamps use `DEFAULT NOW()`
- String fields have appropriate length limits
- Indexes are created for frequently queried fields
- Foreign key constraints are prepared but commented out

## 🔄 Maintenance

### Regular Tasks
1. **Backup Database**: `docker exec echomirror_postgres pg_dump -U postgres echomirror > backup.sql`
2. **Update Dependencies**: `dart pub upgrade`
3. **Clean Docker**: `docker system prune -f`

### Monitoring
- Monitor PostgreSQL logs: `docker compose logs -f postgres`
- Check container resource usage: `docker stats`

## 📚 References

- [Serverpod Documentation](https://docs.serverpod.dev)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Redis Documentation](https://redis.io/documentation)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run verification checks
5. Submit a pull request

## 📄 License

This project is part of the EchoMirror application. See the main project repository for licensing information.
