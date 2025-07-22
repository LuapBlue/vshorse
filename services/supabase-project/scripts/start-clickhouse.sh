#!/bin/bash
# start-clickhouse.sh - Start ClickHouse service

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}Starting ClickHouse...${NC}"

cd "$PROJECT_ROOT"
docker-compose -f docker-compose.clickhouse.yml up -d

echo -e "${GREEN}✓ ClickHouse started${NC}"
echo -e "${BLUE}Access ClickHouse at: ${NC}http://localhost:8123"
