# Supabase Self-Hosted Instance

This is a self-hosted Supabase instance configured for integration with n8n.

## Services Included

### Core Supabase Services

- **PostgreSQL Database** - Main database server with extensions
- **PostgREST** - REST API for your database
- **GoTrue** - Authentication service
- **Storage** - S3-compatible object storage
- **Kong** - API Gateway
- **Studio** - Admin UI
- **Realtime** - Websocket server for real-time subscriptions
- **Supavisor** - Connection pooler
- **Analytics** - Logflare for analytics
- **Functions** - Edge Functions runtime

### Additional Infrastructure

- **Supabase Vault** - Secure secret management (replaces Infisical)
- **Redis** - In-memory data store with FDW integration
- **RabbitMQ** - AMQP message broker for event-driven architectures
- **BullMQ** - Redis-based job queue for background processing
- **Bull Board** - UI for monitoring BullMQ queues

## Access Points

### Supabase Core

- **Supabase Studio**: http://localhost:3000
- **API Gateway**: http://localhost:8000
- **PostgreSQL**: localhost:5432 (session mode)
- **PostgreSQL Pooler**: localhost:6543 (transaction mode)

### Message Queues & Cache

- **RabbitMQ Management**: http://localhost:15672 (rabbitmq/rabbitmq_secure_pass_2025!)
- **Bull Board**: http://localhost:3030
- **Redis**: localhost:6379
- **RabbitMQ AMQP**: localhost:5672

## Quick Start

1. Start all services:

   ```bash
   docker compose -f docker-compose.yml \
     -f docker-compose.redis.yml \
     -f docker-compose.queues.yml up -d
   ```

2. Wait for services to be healthy: `docker compose ps`

3. Access services:
   - Supabase Studio: http://localhost:3000
   - RabbitMQ Management: http://localhost:15672
   - Bull Board: http://localhost:3030

4. Manage secrets:

   ```bash
   ./scripts/setup-supabase-secrets-vault.sh list
   ```

5. Test queues:

   ```bash
   ./test-queues.sh
   ```

## Infrastructure Capabilities

### Secret Management (Vault)

- Secure storage for all credentials and API keys
- Replaced Infisical with native Supabase Vault
- Access via SQL functions or CLI tool
- All secrets encrypted at rest

### Message Queues

- **RabbitMQ**: AMQP broker for event-driven architectures
- **BullMQ**: Redis-based job queue for background tasks
- Unified interface for both queue types
- Automatic job tracking in PostgreSQL
- Built-in monitoring UIs

### Data Storage

- **PostgreSQL**: Primary database with extensions
- **Redis**: In-memory cache with FDW integration
- **S3-compatible Storage**: For files and media

### Integration Features

- Drop-in replacement for apps expecting RabbitMQ or BullMQ
- Foreign Data Wrappers for Redis access via SQL
- Comprehensive monitoring and statistics
- n8n workflow automation support

## n8n Integration

The database is pre-configured with an n8n user and database.
To install n8n, run: `./install-n8n.sh`

## Useful Commands

- View logs: `docker compose logs -f [service_name]`
- Stop services: `docker compose down`
- Restart services: `docker compose restart`
- Update services: `docker compose pull && docker compose up -d`

## Security

Remember to update the default credentials before using in production!
See `credentials.txt` for all generated passwords.
