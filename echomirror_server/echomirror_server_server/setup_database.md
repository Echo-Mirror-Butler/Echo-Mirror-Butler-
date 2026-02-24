# Database Setup Instructions

## Prerequisites
1. Docker Desktop must be installed and running
2. Run this command from the `echomirror_server/echomirror_server_server` directory:

## Setup Commands

```bash
# Start PostgreSQL and Redis containers
docker compose up -d

# Wait for containers to be ready (about 30 seconds)
docker compose logs -f postgres

# Once PostgreSQL is ready, apply migrations manually:
docker exec -i echomirror_postgres psql -U postgres -d echomirror < migrations/20240224000001_create_user_wallets.sql
docker exec -i echomirror_postgres psql -U postgres -d echomirror < migrations/20240224000002_create_gift_transactions.sql

# Verify tables were created
docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\dt"

# Check table structures
docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\d user_wallets"
docker exec -i echomirror_postgres psql -U postgres -d echomirror -c "\d gift_transactions"
```

## Expected Output

The `\dt` command should show:
```
                  List of relations
 Schema |          Name          | Type  |  Owner   
--------+------------------------+-------+----------
 public | gift_transactions     | table | postgres
 public | user_wallets          | table | postgres
```

## Connection Details
- Host: localhost
- Port: 5432
- Database: echomirror
- Username: postgres
- Password: postgres

## Troubleshooting
- If Docker isn't in PATH, restart your terminal/command prompt
- If containers don't start, check Docker Desktop is running
- If migrations fail, check the SQL syntax and PostgreSQL logs
