#!/bin/bash

# Start all Docker services
echo "🚀 Starting all services..."

# Create required networks
echo "Creating Docker networks..."
docker network create traefik-network 2>/dev/null || true
docker network create supabase_default 2>/dev/null || true

# Start Traefik first
echo "Starting Traefik..."
cd services/traefik && docker compose up -d

# Wait a moment for Traefik to be ready
sleep 2

# Start Supabase (core backend services)
echo "Starting Supabase..."
cd ../supabase-project && docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.redis.yml -f docker-compose.queues.yml -f docker-compose.clickhouse.yml up -d

# Wait for Supabase to be ready
echo "Waiting for Supabase to initialize..."
sleep 10

# Check if Supabase is ready
echo "Checking Supabase health..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
  if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ Supabase is ready"
    break
  fi
  echo "Waiting for Supabase... ($counter/$timeout)"
  sleep 5
  counter=$((counter + 5))
done

if [ $counter -ge $timeout ]; then
  echo "⚠️ Warning: Supabase may not be fully ready, but continuing..."
fi

# Start Trigger.dev (background job processing)
echo "Starting Trigger.dev..."
cd ../trigger && docker compose -f webapp/docker-compose.yml up -d

# Wait for Trigger.dev webapp to be ready
echo "Waiting for Trigger.dev webapp..."
sleep 15

# Start Trigger.dev worker
echo "Starting Trigger.dev worker..."
docker compose -f worker/docker-compose.yml up -d

# Start VSCode (browser-based IDE)
echo "Starting VSCode..."
cd ../vscode && docker compose up -d

# Start Socket.io (real-time communication)
echo "Starting Socket.io..."
cd ../socketio && docker compose up -d

echo ""
echo "✅ All services started!"
echo ""
echo -e "\033[1;32m🌐 Service URLs:\033[0m"
echo "- Supabase Studio: http://localhost:3000"
echo "- Supabase API: http://localhost:8000"
echo "- Trigger.dev: http://localhost:8031"
echo "- VSCode: http://localhost:8444"
echo "- Socket.io: http://localhost:3020"
echo "- Traefik Dashboard: http://localhost:8081"
echo ""
echo -e "\033[1;34m🔧 Management UIs:\033[0m"
echo "- RabbitMQ Management: http://localhost:15672"
echo "- Bull Board (Queue monitoring): http://localhost:3030"
echo "- MinIO Console: http://localhost:9003"
echo ""
echo -e "\033[1;33m📋 Service Status Check:\033[0m"

# Function to check service health
check_service() {
  local url=$1
  local name=$2
  if curl -s "$url" >/dev/null 2>&1; then
    echo "✅ $name - Running"
  else
    echo "❌ $name - Not responding"
  fi
}

# Check all services (with retry for Socket.io)
check_service "http://localhost:3000" "Supabase Studio"
check_service "http://localhost:8000/health" "Supabase API"
check_service "http://localhost:8031" "Trigger.dev"
check_service "http://localhost:8444" "VSCode"

# Socket.io might need extra time to fully start
if ! curl -s "http://localhost:3020/health" >/dev/null 2>&1; then
  echo "⏳ Socket.io - Starting up (waiting 10s)..."
  sleep 10
  check_service "http://localhost:3020/health" "Socket.io"
else
  echo "✅ Socket.io - Running"
fi

check_service "http://localhost:8081" "Traefik"

echo ""
echo -e "\033[1;36m🎉 Setup complete! All services should be accessible at the URLs above.\033[0m"
echo -e "\033[0;33m💡 If any service shows as 'Not responding', wait a few minutes for full initialization.\033[0m"
echo ""
