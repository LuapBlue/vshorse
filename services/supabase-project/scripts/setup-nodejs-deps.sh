#!/bin/bash
# setup-nodejs-deps.sh - Install Node.js dependencies and Playwright

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

echo -e "${BLUE}=== Node.js Dependencies Setup ===${NC}"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    echo "Please install Node.js first: https://nodejs.org/"
    exit 1
fi

echo -e "${GREEN}✓ Node.js $(node -v) detected${NC}"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ npm $(npm -v) detected${NC}"

# Change to project directory
cd "$PROJECT_ROOT"

# Install dependencies
echo -e "\n${BLUE}Installing dependencies...${NC}"
npm install

# Install Playwright browsers
echo -e "\n${BLUE}Installing Playwright browsers...${NC}"
npx playwright install

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "${BLUE}You can now run:${NC}"
echo "  npm run build    - Compile TypeScript"
echo "  npm run lint     - Run ESLint"
echo "  npm run test     - Run Playwright tests"
