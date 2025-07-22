#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Stopping Socket.IO Unified Services...${NC}"

# Stop the services
docker-compose down

echo -e "${GREEN}✓ Socket.IO services stopped${NC}"
