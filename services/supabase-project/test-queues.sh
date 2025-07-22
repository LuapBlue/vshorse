#!/bin/bash

# Quick test script for message queues

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================"
echo "🧪 Testing Message Queue Setup"
echo "================================"
echo ""

# Test RabbitMQ
echo -e "${BLUE}Testing RabbitMQ...${NC}"
if curl -s -u rabbitmq:rabbitmq_secure_pass_2025! http://localhost:15672/api/overview > /dev/null 2>&1; then
    echo -e "${GREEN}✓ RabbitMQ Management API is accessible${NC}"
else
    echo -e "${YELLOW}✗ RabbitMQ Management API is not accessible${NC}"
fi

# Test Bull Board
echo -e "${BLUE}Testing Bull Board...${NC}"
if curl -s http://localhost:3030 | grep -q "Bull"; then
    echo -e "${GREEN}✓ Bull Board UI is accessible${NC}"
else
    echo -e "${YELLOW}✗ Bull Board UI is not accessible${NC}"
fi

# Test Redis (for BullMQ)
echo -e "${BLUE}Testing Redis connection...${NC}"
if docker exec supabase-redis redis-cli -a redisSecurePassword123! ping | grep -q PONG; then
    echo -e "${GREEN}✓ Redis is responding${NC}"
else
    echo -e "${YELLOW}✗ Redis is not responding${NC}"
fi

# Test database integration
echo -e "${BLUE}Testing database integration...${NC}"
QUEUE_COUNT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM queues.queue_definitions;" | xargs)
echo -e "${GREEN}✓ Found $QUEUE_COUNT registered queues${NC}"

# Test Vault integration
echo -e "${BLUE}Testing Vault integration...${NC}"
RABBITMQ_URL=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT queues.get_connection_url('rabbitmq');" | xargs)
if [[ $RABBITMQ_URL == amqp://* ]]; then
    echo -e "${GREEN}✓ RabbitMQ connection URL retrieved from Vault${NC}"
else
    echo -e "${YELLOW}✗ Failed to retrieve RabbitMQ connection URL${NC}"
fi

BULLMQ_URL=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT queues.get_connection_url('bullmq');" | xargs)
if [[ $BULLMQ_URL == redis://* ]]; then
    echo -e "${GREEN}✓ BullMQ connection URL retrieved from Vault${NC}"
else
    echo -e "${YELLOW}✗ Failed to retrieve BullMQ connection URL${NC}"
fi

# Create test job
echo -e "${BLUE}Creating test job...${NC}"
JOB_ID=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT queues.bullmq_add_job('test-queue', 'test-job', '{\"test\": true}'::jsonb);" | xargs)
if [[ -n $JOB_ID ]]; then
    echo -e "${GREEN}✓ Test job created with ID: $JOB_ID${NC}"
else
    echo -e "${YELLOW}✗ Failed to create test job${NC}"
fi

echo ""
echo -e "${GREEN}✅ Message queue setup test completed!${NC}"
echo ""
echo "📊 Access the management UIs:"
echo "  - RabbitMQ: http://localhost:15672 (rabbitmq/rabbitmq_secure_pass_2025!)"
echo "  - Bull Board: http://localhost:3030"
echo ""
echo "📝 View queue statistics:"
echo "  docker exec supabase-db psql -U postgres -d postgres -c \"SELECT * FROM queues.queue_stats;\""
echo ""
