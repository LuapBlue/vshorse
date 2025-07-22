#!/bin/bash

# Migration script from Infisical to Supabase Vault
# This script helps migrate secrets and configuration from Infisical to Supabase Vault

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

# Function to store secret in Supabase Vault
store_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    echo -e "${GREEN}[INFO]${NC} Storing secret: $name"
    
    # Escape single quotes in the value
    value="${value//\'/\'\'}"
    description="${description//\'/\'\'}"
    
    execute_sql "SELECT vault.set_secret('$name', '$value', '$description');"
}

echo -e "${GREEN}[INFO]${NC} Setting up Vault and Redis integration..."

# Apply the migration SQL
docker exec -i supabase-db psql -U postgres -d postgres < ./migrations/002_setup_vault_redis_working.sql

echo -e "${GREEN}[INFO]${NC} Migrating secrets to Supabase Vault..."

# Migrate common secrets to Vault
# These are the secrets that were previously stored in Infisical

# Database Configuration
store_secret "DB_HOST" "db" "Database host"
store_secret "DB_NAME" "postgres" "Database name"
store_secret "DB_PORT" "5432" "Database port"
store_secret "DB_PASSWORD" "ZAFWpgNFWIchQxtqbHZ87jC2bZB0oyKI" "Database password"

# JWT & Authentication
store_secret "JWT_SECRET" "YOUR_JWT_SECRET_HERE" "JWT secret key"
store_secret "ANON_KEY" "YOUR_ANON_KEY_HERE" "Anonymous key"
store_secret "SERVICE_ROLE_KEY" "YOUR_SERVICE_ROLE_KEY_HERE" "Service role key"

# Dashboard Access
store_secret "DASHBOARD_USERNAME" "supabase" "Dashboard username"
store_secret "DASHBOARD_PASSWORD" "YOUR_DASHBOARD_PASSWORD_HERE" "Dashboard password"

# Redis Configuration
store_secret "REDIS_PASSWORD" "redisSecurePassword123!" "Redis password"
store_secret "REDIS_URL" "redis://:redisSecurePassword123!@redis:6379/0" "Redis connection URL"

# API Configuration
store_secret "SITE_URL" "http://localhost:8000" "Site URL"
store_secret "API_URL" "http://localhost:8000" "API URL"

# Email Configuration
store_secret "SMTP_HOST" "localhost" "SMTP host"
store_secret "SMTP_PORT" "2500" "SMTP port"
store_secret "SMTP_USER" "" "SMTP username"
store_secret "SMTP_PASSWORD" "" "SMTP password"

# Additional app secrets that were in Infisical
store_secret "APP_SECRET_KEY_BASE" "MRzUkNGTFFmP5B8uHdMN1s6EH4YwjNaT" "Application secret key base"
store_secret "APP_VAULT_ENC_KEY" "CxNbWuY8FhydNFIsVIupKdoimc4nELRP" "Vault encryption key"

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

# Update the Redis server in the database with the actual key_id
echo -e "${GREEN}[INFO]${NC} Updating Redis server configuration..."

REDIS_KEY_ID=$(execute_sql "SELECT id FROM vault.secrets WHERE name = 'redis_connection' LIMIT 1;" | grep -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | xargs)

if [ -n "$REDIS_KEY_ID" ]; then
    execute_sql "DROP SERVER IF EXISTS redis_server CASCADE;"
    execute_sql "CREATE SERVER redis_server FOREIGN DATA WRAPPER redis_wrapper OPTIONS (conn_url_id '$REDIS_KEY_ID');"
    echo -e "${GREEN}[INFO]${NC} Redis server configured with key_id: $REDIS_KEY_ID"
else
    echo -e "${RED}[ERROR]${NC} Failed to get Redis key_id from Vault"
fi

echo ""
echo -e "${GREEN}✅ Migration completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the Vault integration by accessing secrets:"
echo "   docker exec -it supabase-db psql -U postgres -d postgres -c \"SELECT * FROM vault.secrets;\""
echo ""
echo "2. Access Redis through Supabase:"
echo "   docker exec -it supabase-db psql -U postgres -d postgres -c \"SELECT * FROM redis.app_config;\""
echo ""
echo "3. Remove Infisical references from your application code"
echo ""
echo "4. Update your applications to use Supabase Vault instead of Infisical"
echo ""
echo "Vault access example from your application:"
echo "  - Use Supabase client to query: SELECT vault.get_secret('JWT_SECRET');"
echo "  - Or access through the app_configuration view"
