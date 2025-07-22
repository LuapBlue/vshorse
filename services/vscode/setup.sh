#!/bin/bash

# Code-Server Modular App Setup Script

set -e

echo "🚀 Setting up Code-Server Modular App..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}📝 Creating .env file from .env.example...${NC}"
    cp .env.example .env
    
    # Generate secure passwords
    CODE_SERVER_PASSWORD=$(generate_password)
    CODE_SERVER_SUDO_PASSWORD=$(generate_password)
    
    # Replace placeholders in .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/your_password_here/$CODE_SERVER_PASSWORD/g" .env
        sed -i '' "s/your_sudo_password_here/$CODE_SERVER_SUDO_PASSWORD/g" .env
    else
        # Linux
        sed -i "s/your_password_here/$CODE_SERVER_PASSWORD/g" .env
        sed -i "s/your_sudo_password_here/$CODE_SERVER_SUDO_PASSWORD/g" .env
    fi
    
    echo -e "${GREEN}✅ Generated secure passwords${NC}"
    echo -e "${YELLOW}⚠️  Save these credentials:${NC}"
    echo "   Password: $CODE_SERVER_PASSWORD"
    echo "   Sudo Password: $CODE_SERVER_SUDO_PASSWORD"
fi

# Create necessary directories
echo -e "${YELLOW}📁 Creating necessary directories...${NC}"
mkdir -p config workspace
mkdir -p workspace/projects

# Create a welcome file
cat > workspace/README.md << EOF
# Welcome to VSCode!

This is your VS Code workspace running in the browser.

## Quick Start

1. Open the terminal (Ctrl+\` or Cmd+\`)
2. Navigate to your projects: \`cd /home/coder/projects\`
3. Start coding!

## Features

- Full VS Code experience in your browser
- Access from any device
- Pre-installed extensions
- Integrated terminal with sudo access
- Git integration

## Tips

- Your main project directory is mounted at \`/home/coder/projects\`
- Extensions and settings are persisted in the config directory
- Use the integrated terminal for all command-line operations

Happy coding! 🚀
EOF

# Set proper permissions
echo -e "${YELLOW}🔒 Setting permissions...${NC}"
chmod 755 config workspace
chmod 644 workspace/README.md

# Install Playwright
echo -e "${YELLOW}🎭 Installing Playwright...${NC}"
if command -v npm &> /dev/null; then
    npm install -g playwright@latest
    npx playwright install
    echo -e "${GREEN}✅ Playwright installed successfully${NC}"
else
    echo -e "${YELLOW}⚠️  npm not found. Playwright will be installed when you start vscode${NC}"
fi

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Review and update .env file if needed"
echo "2. docker compose -f supabase-project/docker-compose.yml -f apps/vscode/docker-compose.override.yml up -d"
echo "3. Access VSCode at https://localhost:8443"
echo "4. Use the password from .env file to log in"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "- Your project files are mounted at /home/coder/projects"
echo "- Extensions and settings are saved in ./config"
echo "- The connection uses HTTPS (self-signed certificate)"
