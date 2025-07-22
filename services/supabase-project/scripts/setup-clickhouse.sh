#!/bin/bash
# setup-clickhouse.sh - Setup ClickHouse integration with Supabase

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== ClickHouse Integration Setup ===${NC}"

# Check if .env file exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found in $PROJECT_ROOT${NC}"
    exit 1
fi

# Load environment variables
source "$PROJECT_ROOT/.env"

# Check if ClickHouse variables are set
if [ -z "${CLICKHOUSE_USER:-}" ] || [ -z "${CLICKHOUSE_PASSWORD:-}" ]; then
    echo -e "${RED}Error: ClickHouse environment variables not set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment variables loaded${NC}"

# Function to wait for service
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service on port $port...${NC}"
    
    while ! nc -z localhost $port 2>/dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}✗ $service failed to start after $max_attempts attempts${NC}"
            return 1
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    echo -e "\n${GREEN}✓ $service is ready${NC}"
    return 0
}

# Start ClickHouse container
echo -e "\n${BLUE}Starting ClickHouse container...${NC}"
cd "$PROJECT_ROOT"
docker-compose -f docker-compose.clickhouse.yml up -d

# Wait for ClickHouse to be ready
if ! wait_for_service "ClickHouse" "${CLICKHOUSE_HTTP_PORT:-8123}"; then
    echo -e "${RED}Failed to start ClickHouse${NC}"
    exit 1
fi

# Create ClickHouse database and tables
echo -e "\n${BLUE}Creating ClickHouse tables...${NC}"

# Create analytics database
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --query="CREATE DATABASE IF NOT EXISTS analytics"

# Create events table
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --database="analytics" \
    --query="
CREATE TABLE IF NOT EXISTS events (
    event_id UUID,
    event_type String,
    user_id UUID,
    properties String,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (created_at, event_type, user_id)
PARTITION BY toYYYYMM(created_at)"

# Create metrics table
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --database="analytics" \
    --query="
CREATE TABLE IF NOT EXISTS metrics (
    metric_name String,
    value Float64,
    tags Map(String, String),
    timestamp DateTime
) ENGINE = MergeTree()
ORDER BY (metric_name, timestamp)
PARTITION BY toYYYYMM(timestamp)"

# Create logs table
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --database="analytics" \
    --query="
CREATE TABLE IF NOT EXISTS logs (
    log_id UUID,
    level String,
    message String,
    service String,
    metadata String,
    timestamp DateTime
) ENGINE = MergeTree()
ORDER BY (timestamp, level, service)
PARTITION BY toYYYYMM(timestamp)"

# Create user_analytics table
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --database="analytics" \
    --query="
CREATE TABLE IF NOT EXISTS user_analytics (
    user_id UUID,
    session_id UUID,
    page_views UInt32,
    total_time_seconds UInt32,
    last_seen DateTime,
    properties Map(String, String)
) ENGINE = ReplacingMergeTree(last_seen)
ORDER BY (user_id, session_id)"

echo -e "${GREEN}✓ ClickHouse tables created${NC}"

# Apply PostgreSQL migrations
echo -e "\n${BLUE}Applying PostgreSQL migrations...${NC}"

# Check if PostgreSQL is running
if ! wait_for_service "PostgreSQL" "5432"; then
    echo -e "${RED}PostgreSQL is not running. Please start Supabase first.${NC}"
    exit 1
fi

# Execute migration with environment variables
PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h localhost \
    -p 5432 \
    -U postgres \
    -d postgres \
    -v app.clickhouse_user="${CLICKHOUSE_USER}" \
    -v app.clickhouse_password="${CLICKHOUSE_PASSWORD}" \
    -v app.clickhouse_db="${CLICKHOUSE_DB}" \
    -f "$PROJECT_ROOT/migrations/004_setup_clickhouse.sql"

echo -e "${GREEN}✓ PostgreSQL migrations applied${NC}"

# Create foreign tables
echo -e "\n${BLUE}Creating foreign tables...${NC}"
PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h localhost \
    -p 5432 \
    -U postgres \
    -d postgres \
    -f "$PROJECT_ROOT/migrations/005_create_foreign_tables.sql"

echo -e "${GREEN}✓ Foreign tables created${NC}"

# Test the connection
echo -e "\n${BLUE}Testing ClickHouse connection...${NC}"
docker exec -i supabase-clickhouse clickhouse-client \
    --user="${CLICKHOUSE_USER}" \
    --password="${CLICKHOUSE_PASSWORD}" \
    --query="SELECT 'ClickHouse connection successful' as status"

echo -e "\n${GREEN}=== ClickHouse Setup Complete ===${NC}"
echo -e "${BLUE}ClickHouse HTTP interface available at: ${NC}http://localhost:${CLICKHOUSE_HTTP_PORT:-8123}"
echo -e "${BLUE}Username: ${NC}${CLICKHOUSE_USER}"
echo -e "${YELLOW}Note: Use the password from your .env file${NC}"
