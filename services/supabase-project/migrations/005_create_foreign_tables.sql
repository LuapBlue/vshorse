-- 005_create_foreign_tables.sql
-- Create foreign tables to access ClickHouse data from PostgreSQL

-- Ensure we're using the clickhouse schema
SET search_path TO clickhouse, public;

-- Create foreign table for events
CREATE FOREIGN TABLE IF NOT EXISTS events (
    event_id UUID,
    event_type text,
    user_id UUID,
    properties text,
    created_at timestamp
) SERVER clickhouse_server 
OPTIONS (
    database 'analytics',
    table 'events'
);

-- Create foreign table for metrics
CREATE FOREIGN TABLE IF NOT EXISTS metrics (
    metric_name text,
    value double precision,
    tags text,  -- ClickHouse Map type represented as text (JSON)
    timestamp timestamp
) SERVER clickhouse_server 
OPTIONS (
    database 'analytics',
    table 'metrics'
);

-- Create foreign table for logs
CREATE FOREIGN TABLE IF NOT EXISTS logs (
    log_id UUID,
    level text,
    message text,
    service text,
    metadata text,
    timestamp timestamp
) SERVER clickhouse_server 
OPTIONS (
    database 'analytics',
    table 'logs'
);

-- Create foreign table for user_analytics
CREATE FOREIGN TABLE IF NOT EXISTS user_analytics (
    user_id UUID,
    session_id UUID,
    page_views integer,
    total_time_seconds integer,
    last_seen timestamp,
    properties text  -- ClickHouse Map type as text
) SERVER clickhouse_server 
OPTIONS (
    database 'analytics',
    table 'user_analytics'
);

-- Grant permissions on foreign tables
GRANT SELECT ON ALL TABLES IN SCHEMA clickhouse TO authenticated;
GRANT SELECT, INSERT ON clickhouse.events TO authenticated;
GRANT SELECT, INSERT ON clickhouse.metrics TO authenticated;
GRANT SELECT, INSERT ON clickhouse.logs TO service_role;
GRANT SELECT ON clickhouse.user_analytics TO authenticated;

-- Create helper function for batch inserts
CREATE OR REPLACE FUNCTION clickhouse.batch_insert_events(
    events jsonb[]
)
RETURNS integer AS $$
DECLARE
    inserted_count integer := 0;
    event_record jsonb;
BEGIN
    FOREACH event_record IN ARRAY events
    LOOP
        INSERT INTO clickhouse.events (
            event_id,
            event_type,
            user_id,
            properties,
            created_at
        ) VALUES (
            COALESCE((event_record->>'event_id')::uuid, gen_random_uuid()),
            event_record->>'event_type',
            (event_record->>'user_id')::uuid,
            COALESCE(event_record->>'properties', '{}'),
            COALESCE((event_record->>'created_at')::timestamp, now())
        );
        inserted_count := inserted_count + 1;
    END LOOP;
    
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on batch insert function
GRANT EXECUTE ON FUNCTION clickhouse.batch_insert_events(jsonb[]) TO authenticated;

-- Create a view for common analytics queries
CREATE OR REPLACE VIEW clickhouse.event_summary AS
SELECT 
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    MAX(created_at) as last_event,
    MIN(created_at) as first_event
FROM clickhouse.events
GROUP BY event_type;

GRANT SELECT ON clickhouse.event_summary TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Foreign tables created successfully';
    RAISE NOTICE 'You can now query ClickHouse data using:';
    RAISE NOTICE 'SELECT * FROM clickhouse.events;';
    RAISE NOTICE 'SELECT * FROM clickhouse.metrics;';
END $$;
