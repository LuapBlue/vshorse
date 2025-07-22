#!/bin/bash

# Example script showing how to use Supabase Vault instead of Infisical
# This demonstrates various ways to access secrets

set -e



# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================"
echo "📚 Supabase Vault Usage Examples"
echo "================================"
echo ""

# Example 1: Get a single secret
echo -e "${BLUE}Example 1: Get a single secret${NC}"
echo "Command: ./scripts/setup-supabase-secrets-vault.sh get JWT_SECRET"
JWT_SECRET=$(./scripts/setup-supabase-secrets-vault.sh get JWT_SECRET)
echo "Result: JWT_SECRET = ${JWT_SECRET:0:20}..."
echo ""

# Example 2: List all secrets
echo -e "${BLUE}Example 2: List all secrets${NC}"
echo "Command: ./scripts/setup-supabase-secrets-vault.sh list"
./scripts/setup-supabase-secrets-vault.sh list | head -10
echo "..."
echo ""

# Example 3: Set a new secret
echo -e "${BLUE}Example 3: Set a new secret${NC}"
echo "Command: ./scripts/setup-supabase-secrets-vault.sh set MY_NEW_SECRET \"secret_value\" \"Description\""
./scripts/setup-supabase-secrets-vault.sh set EXAMPLE_SECRET "example_value_123" "Example secret for demo"
echo ""

# Example 4: Access from application code (SQL examples)
echo -e "${BLUE}Example 4: SQL queries for application access${NC}"
echo ""
echo "Direct query:"
echo "  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'JWT_SECRET';"
echo ""
echo "Using app_configuration view (combines Vault and Redis):"
echo "  SELECT * FROM app_configuration WHERE key = 'JWT_SECRET';"
echo ""

# Example 5: Environment variable export
echo -e "${BLUE}Example 5: Export secrets as environment variables${NC}"
echo ""
echo "You can create a script to export all secrets:"
cat << 'EOF'
#!/bin/bash
# export-vault-env.sh
eval $(docker exec supabase-db psql -U postgres -d postgres -t -c \
  "SELECT 'export ' || name || '=\"' || decrypted_secret || '\"' 
   FROM vault.decrypted_secrets 
   WHERE name NOT LIKE '%PASSWORD%' AND name NOT LIKE '%KEY%';" | grep -v '^$')
EOF
echo ""

# Example 6: Docker Compose integration
echo -e "${BLUE}Example 6: Docker Compose usage${NC}"
echo ""
echo "For Docker Compose services, you can create a .env file from Vault:"
echo "  docker exec supabase-db psql -U postgres -d postgres -t -c \\"
echo "    \"SELECT name || '=' || decrypted_secret FROM vault.decrypted_secrets;\" > .env.vault"
echo ""

# Example 7: Application configuration
echo -e "${BLUE}Example 7: Application configuration pattern${NC}"
echo ""
echo "JavaScript/TypeScript example:"
cat << 'EOF'
// config.js
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function getConfig(key) {
  const { data, error } = await supabase
    .from('decrypted_secrets')
    .select('decrypted_secret')
    .eq('name', key)
    .single();
  
  return data?.decrypted_secret;
}

// Usage
const jwtSecret = await getConfig('JWT_SECRET');
EOF
echo ""

echo -e "${GREEN}✅ Migration Comparison${NC}"
echo ""
echo "Before (Infisical):"
echo "  infisical secrets get JWT_SECRET --projectId=... --env=dev"
echo ""
echo "After (Supabase Vault):"
echo "  ./scripts/setup-supabase-secrets-vault.sh get JWT_SECRET"
echo ""
echo "Or directly in your app:"
echo "  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'JWT_SECRET';"
echo ""
