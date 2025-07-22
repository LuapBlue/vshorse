#!/bin/bash

# Stop all Docker services
echo "🛑 Stopping all services..."

# Stop services in reverse order
cd services/socketio && docker compose down
cd ../vscode && docker compose down
cd ../trigger && docker compose -f webapp/docker-compose.yml down && docker compose -f worker/docker-compose.yml down
cd ../supabase-project && docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.redis.yml -f docker-compose.queues.yml -f docker-compose.clickhouse.yml down
cd ../traefik && docker compose down

echo "✅ All services stopped!"
