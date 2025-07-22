#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Socket.IO Unified Services...${NC}"

# Load environment variables from parent .env if exists
if [ -f "../../.env" ]; then
    export $(cat ../../.env | grep -v '^#' | xargs)
else
    echo -e "${RED}Warning: .env file not found in parent directory${NC}"
fi

# Copy .env from socketio-app if needed
if [ ! -f ".env" ] && [ -f "../socketio-app/.env" ]; then
    echo -e "${YELLOW}Copying .env from socketio-app...${NC}"
    cp ../socketio-app/.env .
fi

# Start the services
echo -e "${YELLOW}Starting Socket.IO server and admin panel...${NC}"
docker-compose up -d

# Check if services started successfully
sleep 5
if docker ps | grep -q socketio-server && docker ps | grep -q socketio-admin; then
    echo -e "${GREEN}✓ Socket.IO services started successfully!${NC}"
    echo -e "${GREEN}  - Socket.IO Server: http://localhost:3020${NC}"
    echo -e "${GREEN}  - Socket.IO Admin: http://localhost:3021${NC}"
else
    echo -e "${RED}✗ Failed to start Socket.IO services${NC}"
    docker-compose logs
fi
