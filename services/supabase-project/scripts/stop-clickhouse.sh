#!/bin/bash
# stop-clickhouse.sh - Stop ClickHouse service

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}Stopping ClickHouse...${NC}"

cd "$PROJECT_ROOT"
docker-compose -f docker-compose.clickhouse.yml down

echo -e "${GREEN}✓ ClickHouse stopped${NC}"
