#!/bin/bash

# Generate secure secrets
SESSION_SECRET=$(openssl rand -hex 16)
MAGIC_LINK_SECRET=$(openssl rand -hex 16)
ENCRYPTION_KEY=$(openssl rand -hex 16)
MANAGED_WORKER_SECRET=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
CLICKHOUSE_PASSWORD=$(openssl rand -hex 16)
DOCKER_REGISTRY_PASSWORD=$(openssl rand -hex 16)
OBJECT_STORE_SECRET_ACCESS_KEY=$(openssl rand -hex 16)
MINIO_ROOT_PASSWORD=$(openssl rand -hex 16)

cat > .env << EOF
# Trigger.dev self-hosting environment variables

# Secrets
SESSION_SECRET=${SESSION_SECRET}
MAGIC_LINK_SECRET=${MAGIC_LINK_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}
MANAGED_WORKER_SECRET=${MANAGED_WORKER_SECRET}

# Worker token (will be set after webapp starts)
# TRIGGER_WORKER_TOKEN=

# Postgres - Using a different port to avoid conflicts
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/trigger?schema=public&sslmode=disable
DIRECT_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/trigger?schema=public&sslmode=disable

# Trigger image tag
TRIGGER_IMAGE_TAG=v4-beta

# Webapp URLs - Using port 8031 to avoid conflicts
APP_ORIGIN=http://localhost:8031
LOGIN_ORIGIN=http://localhost:8031
API_ORIGIN=http://localhost:8031
DEV_OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:8031/otel

# ClickHouse
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD}
CLICKHOUSE_URL=http://default:${CLICKHOUSE_PASSWORD}@clickhouse:8123?secure=false
RUN_REPLICATION_CLICKHOUSE_URL=http://default:${CLICKHOUSE_PASSWORD}@clickhouse:8123

# Docker Registry
DOCKER_REGISTRY_URL=localhost:5001
DOCKER_REGISTRY_USERNAME=registry-user
DOCKER_REGISTRY_PASSWORD=${DOCKER_REGISTRY_PASSWORD}

# Object store
OBJECT_STORE_ACCESS_KEY_ID=admin
OBJECT_STORE_SECRET_ACCESS_KEY=${OBJECT_STORE_SECRET_ACCESS_KEY}
OBJECT_STORE_BASE_URL=http://localhost:9002
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}

# Publish IPs
WEBAPP_PUBLISH_IP=0.0.0.0
POSTGRES_PUBLISH_IP=127.0.0.1
REDIS_PUBLISH_IP=127.0.0.1
CLICKHOUSE_PUBLISH_IP=127.0.0.1
REGISTRY_PUBLISH_IP=127.0.0.1
MINIO_PUBLISH_IP=127.0.0.1

# Restart policy
RESTART_POLICY=unless-stopped

# Docker logging
LOGGING_DRIVER=local
LOGGING_MAX_SIZE=20m
LOGGING_MAX_FILES=5
LOGGING_COMPRESS=true
EOF

echo "Generated .env file with secure secrets"
