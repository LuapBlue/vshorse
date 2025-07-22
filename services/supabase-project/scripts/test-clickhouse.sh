#!/bin/bash
# test-clickhouse.sh - Test ClickHouse integration

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

echo -e "${BLUE}=== ClickHouse Integration Tests ===${NC}"

# Load environment variables
source "$PROJECT_ROOT/.env"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Container is running
run_test "ClickHouse container running" \
    "docker ps | grep -q supabase-clickhouse"

# Test 2: HTTP interface is accessible
run_test "ClickHouse HTTP interface" \
    "curl -s http://localhost:${CLICKHOUSE_HTTP_PORT:-8123}/ping"

# Test 3: Can connect with credentials
run_test "ClickHouse authentication" \
    "docker exec supabase-clickhouse clickhouse-client \
        --user='${CLICKHOUSE_USER}' \
        --password='${CLICKHOUSE_PASSWORD}' \
        --query='SELECT 1'"

# Test 4: Analytics database exists
run_test "Analytics database exists" \
    "docker exec supabase-clickhouse clickhouse-client \
        --user='${CLICKHOUSE_USER}' \
        --password='${CLICKHOUSE_PASSWORD}' \
        --query='SHOW DATABASES' | grep -q analytics"

# Test 5: Tables exist
run_test "Events table exists" \
    "docker exec supabase-clickhouse clickhouse-client \
        --user='${CLICKHOUSE_USER}' \
        --password='${CLICKHOUSE_PASSWORD}' \
        --database='analytics' \
        --query='EXISTS TABLE events'"

# Test 6: Can insert data
run_test "Insert test data" \
    "docker exec supabase-clickhouse clickhouse-client \
        --user='${CLICKHOUSE_USER}' \
        --password='${CLICKHOUSE_PASSWORD}' \
        --database='analytics' \
        --query=\"INSERT INTO events (event_id, event_type, user_id, properties) \
        VALUES (generateUUIDv4(), 'test_event', generateUUIDv4(), '{}')\""

# Test 7: PostgreSQL FDW exists
run_test "PostgreSQL FDW configured" \
    "PGPASSWORD='${POSTGRES_PASSWORD}' psql -h localhost -p 5432 -U postgres -d postgres \
        -c \"SELECT 1 FROM pg_foreign_data_wrapper WHERE fdwname = 'clickhouse_wrapper'\" | grep -q '1 row'"

# Test 8: Foreign server exists
run_test "Foreign server exists" \
    "PGPASSWORD='${POSTGRES_PASSWORD}' psql -h localhost -p 5432 -U postgres -d postgres \
        -c \"SELECT 1 FROM pg_foreign_server WHERE srvname = 'clickhouse_server'\" | grep -q '1 row'"

# Test 9: Schema exists
run_test "ClickHouse schema exists" \
    "PGPASSWORD='${POSTGRES_PASSWORD}' psql -h localhost -p 5432 -U postgres -d postgres \
        -c \"SELECT 1 FROM information_schema.schemata WHERE schema_name = 'clickhouse'\" | grep -q '1 row'"

# Test 10: Helper functions exist
run_test "Helper functions exist" \
    "PGPASSWORD='${POSTGRES_PASSWORD}' psql -h localhost -p 5432 -U postgres -d postgres \
        -c \"SELECT 1 FROM pg_proc WHERE proname = 'insert_event' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'clickhouse')\" | grep -q '1 row'"

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed! ClickHouse integration is working correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed. Please check the configuration.${NC}"
    exit 1
fi
