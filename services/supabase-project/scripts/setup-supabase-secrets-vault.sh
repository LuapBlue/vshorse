#!/bin/bash

# Script to manage Supabase secrets using Vault instead of Infisical

set -e

# Colors for output  
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔐 Managing Supabase secrets with Vault..."

# Function to set a secret in Vault
set_vault_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    docker exec -i supabase-db psql -U postgres -d postgres -c \
        "SELECT vault.set_secret('$name', '$value', '$description');"
}

# Function to get a secret from Vault
get_vault_secret() {
    local name=$1
    
    docker exec -i supabase-db psql -U postgres -d postgres -t -c \
        "SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = '$name';" | xargs
}

# Function to list all secrets
list_vault_secrets() {
    docker exec -i supabase-db psql -U postgres -d postgres -c \
        "SELECT name, description, created_at FROM vault.secrets ORDER BY name;"
}

# Parse command
case "$1" in
    set)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 set <name> <value> [description]"
            exit 1
        fi
        set_vault_secret "$2" "$3" "${4:-''}"
        echo -e "${GREEN}✅ Secret '$2' stored successfully${NC}"
        ;;
    get)
        if [ -z "$2" ]; then
            echo "Usage: $0 get <name>"
            exit 1
        fi
        value=$(get_vault_secret "$2")
        echo "$value"
        ;;
    list)
        list_vault_secrets
        ;;
    *)
        echo "Usage: $0 {set|get|list}"
        echo "  set <name> <value> [description] - Store a secret"
        echo "  get <name>                       - Retrieve a secret"
        echo "  list                             - List all secrets"
        exit 1
        ;;
esac
