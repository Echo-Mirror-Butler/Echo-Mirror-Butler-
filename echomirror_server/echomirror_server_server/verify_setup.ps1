# PowerShell script to verify database setup
Write-Host "=== EchoMirror Database Setup Verification ===" -ForegroundColor Green

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running or not in PATH" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and restart your terminal" -ForegroundColor Yellow
    exit 1
}

# Check if containers are running
$postgres = docker ps --filter "name=echomirror_postgres" --format "table {{.Names}}"
$redis = docker ps --filter "name=echomirror_redis" --format "table {{.Names}}"

if ($postgres -match "echomirror_postgres") {
    Write-Host "✓ PostgreSQL container is running" -ForegroundColor Green
} else {
    Write-Host "✗ PostgreSQL container is not running" -ForegroundColor Red
    Write-Host "Run: docker compose up -d" -ForegroundColor Yellow
}

if ($redis -match "echomirror_redis") {
    Write-Host "✓ Redis container is running" -ForegroundColor Green
} else {
    Write-Host "✗ Redis container is not running" -ForegroundColor Red
    Write-Host "Run: docker compose up -d" -ForegroundColor Yellow
}

# Check if tables exist
if ($postgres -match "echomirror_postgres") {
    try {
        $tables = docker exec echomirror_postgres psql -U postgres -d echomirror -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';"
        if ($tables -match "user_wallets" -and $tables -match "gift_transactions") {
            Write-Host "✓ Database tables exist: user_wallets, gift_transactions" -ForegroundColor Green
        } else {
            Write-Host "✗ Database tables are missing" -ForegroundColor Red
            Write-Host "Run the migration commands from setup_database.md" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ Cannot connect to database" -ForegroundColor Red
    }
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Ensure migrations are applied (see setup_database.md)" -ForegroundColor White
Write-Host "2. Start the Serverpod server: dart run bin/main.dart" -ForegroundColor White
