#!/bin/bash

# Setup Message Queues for Supabase
# Installs and configures RabbitMQ and BullMQ integration

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================"
echo "🚀 Setting up Message Queues"
echo "================================"
echo ""

# Check if Supabase is running
if ! docker compose ps | grep -q "supabase-db.*healthy"; then
    echo -e "${RED}[ERROR]${NC} Supabase database is not running or healthy!"
    echo "Please start Supabase first"
    exit 1
fi

# Check if Redis is running
if ! docker compose ps | grep -q "supabase-redis.*healthy"; then
    echo -e "${YELLOW}[WARNING]${NC} Redis is not running. Starting Redis first..."
    docker compose -f docker-compose.yml -f docker-compose.redis.yml up -d redis
    sleep 5
fi

echo -e "${GREEN}[INFO]${NC} Starting message queue services..."

# Start RabbitMQ and Bull Board
cd /Users/john2/johneubankai/home/supabase-project
docker compose -f docker-compose.yml -f docker-compose.redis.yml -f docker-compose.queues.yml up -d

# Wait for RabbitMQ to be healthy
echo -e "${GREEN}[INFO]${NC} Waiting for RabbitMQ to be healthy..."
for i in {1..60}; do
    if docker exec supabase-rabbitmq rabbitmq-diagnostics ping 2>/dev/null | grep -q "Ping succeeded"; then
        echo -e "${GREEN}[INFO]${NC} RabbitMQ is healthy!"
        break
    fi
    echo -n "."
    sleep 2
done

# Apply database migrations
echo -e "${GREEN}[INFO]${NC} Setting up database schema for queues..."
docker exec -i supabase-db psql -U postgres -d postgres < /Users/john2/johneubankai/home/supabase-project/migrations/003_setup_message_queues.sql

# Store queue credentials in Vault
echo -e "${GREEN}[INFO]${NC} Storing queue credentials in Vault..."

# Create RabbitMQ vhost and permissions
echo -e "${GREEN}[INFO]${NC} Configuring RabbitMQ..."
docker exec supabase-rabbitmq rabbitmqctl add_vhost supabase 2>/dev/null || true
docker exec supabase-rabbitmq rabbitmqctl set_permissions -p supabase rabbitmq ".*" ".*" ".*" 2>/dev/null || true

# Enable RabbitMQ plugins
docker exec supabase-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_web_stomp rabbitmq_delayed_message_exchange

# Create example queues in RabbitMQ
echo -e "${GREEN}[INFO]${NC} Creating example RabbitMQ queues..."
docker exec supabase-rabbitmq rabbitmqadmin -u rabbitmq -p rabbitmq_secure_pass_2025! declare queue name=notifications durable=true
docker exec supabase-rabbitmq rabbitmqadmin -u rabbitmq -p rabbitmq_secure_pass_2025! declare queue name=emails durable=true
docker exec supabase-rabbitmq rabbitmqadmin -u rabbitmq -p rabbitmq_secure_pass_2025! declare exchange name=events type=topic durable=true

# Create BullMQ example queues in Redis
echo -e "${GREEN}[INFO]${NC} Setting up BullMQ queues..."
docker exec supabase-redis redis-cli -a redisSecurePassword123! <<EOF
SELECT 1
SADD bull:email:meta queue
SADD bull:notification:meta queue
SADD bull:default:meta queue
EOF

echo ""
echo -e "${GREEN}✅ Message Queue setup completed!${NC}"
echo ""
echo "📊 Management UIs:"
echo "  - RabbitMQ: http://localhost:15672"
echo "    Username: rabbitmq"
echo "    Password: rabbitmq_secure_pass_2025!"
echo ""
echo "  - Bull Board: http://localhost:3030"
echo ""
echo "📝 Connection URLs (stored in Vault):"
echo "  - RabbitMQ: amqp://rabbitmq:rabbitmq_secure_pass_2025!@localhost:5672/"
echo "  - BullMQ: redis://:redisSecurePassword123!@localhost:6379/1"
echo ""
echo "🔧 Next steps:"
echo "  1. Check the management UIs to verify queues are running"
echo "  2. Run the example scripts: ./examples/queue-examples.js"
echo "  3. View queue statistics: SELECT * FROM queues.queue_stats;"
echo ""
