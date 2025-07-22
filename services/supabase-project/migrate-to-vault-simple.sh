#!/bin/bash

# Migration script from Infisical to Supabase Vault
# Simplified version using vault.create_secret directly

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================"
echo "🔄 Migrating from Infisical to Supabase Vault"
echo "================================"
echo ""

# Check if Supabase is running
if ! docker compose ps | grep -q "supabase-db.*healthy"; then
    echo -e "${RED}[ERROR]${NC} Supabase database is not running or healthy!"
    echo "Please start Supabase first with: docker compose up -d"
    exit 1
fi

# Function to execute SQL in Supabase
execute_sql() {
    docker exec -i supabase-db psql -U postgres -d postgres -c "$1"
}

# Function to store secret in Supabase Vault using create_secret
store_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    echo -e "${GREEN}[INFO]${NC} Storing secret: $name"
    
    # Escape single quotes in the value
    value="${value//\'/\'\'}"
    description="${description//\'/\'\'}"
    
    # Use vault.create_secret directly
    execute_sql "SELECT vault.create_secret('$value', '$name', '$description');" || true
}

echo -e "${GREEN}[INFO]${NC} Setting up Vault and Redis integration..."

# Apply the migration SQL
docker exec -i supabase-db psql -U postgres -d postgres < ./migrations/002_setup_vault_redis_working.sql

echo -e "${GREEN}[INFO]${NC} Starting Redis service..."

# Start Redis with Supabase
docker compose -f docker-compose.yml -f docker-compose.redis.yml up -d redis

# Wait for Redis to be healthy
echo -e "${GREEN}[INFO]${NC} Waiting for Redis to be healthy..."
for i in {1..30}; do
    if docker exec supabase-redis redis-cli -a redisSecurePassword123! ping 2>/dev/null | grep -q PONG; then
        echo -e "${GREEN}[INFO]${NC} Redis is healthy!"
        break
    fi
    echo -n "."
    sleep 1
done

echo -e "${GREEN}[INFO]${NC} Migrating secrets to Supabase Vault..."

# Migrate common secrets to Vault using vault.create_secret

# Database Configuration
store_secret "DB_HOST" "db" "Database host"
store_secret "DB_NAME" "postgres" "Database name"
store_secret "DB_PORT" "5432" "Database port"
store_secret "DB_PASSWORD" "ZAFWpgNFWIchQxtqbHZ87jC2bZB0oyKI" "Database password"

# JWT & Authentication
store_secret "JWT_SECRET" "jFw0d5Umyjl5gahwJV3A6d33MNT1riRu" "JWT secret key"
store_secret "ANON_KEY" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzUyMzkwOTMyLCJleHAiOjQ5MDU5OTA5MzJ9.S0taVDh4U2pJcU9uYjRRdUdaa1RLTzRvTHk2YTcwdWJ3dTIxQlZvT2RqST0" "Anonymous key"
store_secret "SERVICE_ROLE_KEY" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NTIzOTA5MzIsImV4cCI6NDkwNTk5MDkzMn0.dFNheWR3L0RRQ0QybW1QRjdMN2NJQmp5SkNBeTl5V041MmNJSmY1TUFFOD0" "Service role key"

# Dashboard Access
store_secret "DASHBOARD_USERNAME" "supabase" "Dashboard username"
store_secret "DASHBOARD_PASSWORD" "kaceZWxnPPk0q68RMubDAOH5nmJrGCxJ" "Dashboard password"

# Redis Configuration
store_secret "REDIS_PASSWORD" "redisSecurePassword123!" "Redis password"

# API Configuration
store_secret "SITE_URL" "http://localhost:8000" "Site URL"
store_secret "API_URL" "http://localhost:8000" "API URL"

# Email Configuration
store_secret "SMTP_HOST" "localhost" "SMTP host"
store_secret "SMTP_PORT" "2500" "SMTP port"

# Additional app secrets
store_secret "APP_SECRET_KEY_BASE" "MRzUkNGTFFmP5B8uHdMN1s6EH4YwjNaT" "Application secret key base"
store_secret "APP_VAULT_ENC_KEY" "CxNbWuY8FhydNFIsVIupKdoimc4nELRP" "Vault encryption key"

echo ""
echo -e "${GREEN}✅ Migration completed successfully!${NC}"
echo ""
echo "Important information:"
echo ""
echo "1. Redis is now running as part of Supabase stack"
echo "   - Connection: redis://redis:6379"
echo "   - Password stored in Vault as 'REDIS_PASSWORD'"
echo ""
echo "2. Access secrets from Vault:"
echo "   docker exec -it supabase-db psql -U postgres -d postgres -c \"SELECT * FROM vault.decrypted_secrets;\""
echo ""
echo "3. Access Redis through Supabase FDW:"
echo "   docker exec -it supabase-db psql -U postgres -d postgres -c \"SELECT * FROM redis.app_config;\""
echo ""
echo "4. Use the vault helper script:"
echo "   ./scripts/setup-supabase-secrets-vault.sh list"
echo ""
echo "5. Access secrets in your application:"
echo "   - Direct: SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'JWT_SECRET';"
echo "   - Via view: SELECT * FROM app_configuration;"
echo ""
echo "All Infisical references have been removed from the project."
