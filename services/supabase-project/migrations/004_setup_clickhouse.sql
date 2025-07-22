-- 004_setup_clickhouse.sql
-- Setup ClickHouse Foreign Data Wrapper and analytics infrastructure

-- Enable necessary extensions if not already enabled
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create ClickHouse Foreign Data Wrapper
-- Note: The wrappers extension should already be installed
DO $$
BEGIN
    -- Check if the FDW exists before creating
    IF NOT EXISTS (
        SELECT 1 FROM pg_foreign_data_wrapper 
        WHERE fdwname = 'clickhouse_wrapper'
    ) THEN
        CREATE FOREIGN DATA WRAPPER clickhouse_wrapper 
            HANDLER click_house_fdw_handler 
            VALIDATOR click_house_fdw_validator;
    END IF;
END $$;

-- Store ClickHouse connection credentials in Vault
DO $$
DECLARE
    vault_key_id text;
    ch_user text := current_setting('app.clickhouse_user', true);
    ch_password text := current_setting('app.clickhouse_password', true);
    ch_db text := current_setting('app.clickhouse_db', true);
    connection_string text;
BEGIN
    -- Use environment variables or defaults
    ch_user := COALESCE(ch_user, 'default');
    ch_password := COALESCE(ch_password, 'clickhouse_password');
    ch_db := COALESCE(ch_db, 'default');
    
    -- Construct connection string
    connection_string := format('tcp://%s:%s@clickhouse:9000/%s', 
        ch_user, ch_password, ch_db);
    
    -- Store in vault
    SELECT id INTO vault_key_id
    FROM vault.create_secret(
        connection_string,
        'clickhouse_connection',
        'ClickHouse connection for analytics'
    );
    
    -- Store the key ID for later use
    INSERT INTO vault.decrypted_secrets (name, decrypted_secret, description)
    VALUES ('clickhouse_vault_key_id', vault_key_id, 'Vault key ID for ClickHouse connection')
    ON CONFLICT (name) DO UPDATE SET decrypted_secret = vault_key_id;
END $$;

-- Create ClickHouse server using stored credentials
DO $$
DECLARE
    vault_key_id text;
BEGIN
    -- Get the vault key ID
    SELECT decrypted_secret INTO vault_key_id
    FROM vault.decrypted_secrets
    WHERE name = 'clickhouse_vault_key_id';
    
    -- Create foreign server if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_foreign_server 
        WHERE srvname = 'clickhouse_server'
    ) THEN
        EXECUTE format('CREATE SERVER clickhouse_server 
            FOREIGN DATA WRAPPER clickhouse_wrapper 
            OPTIONS (conn_string_id %L)', vault_key_id);
    END IF;
END $$;

-- Create dedicated schema for ClickHouse tables
CREATE SCHEMA IF NOT EXISTS clickhouse;
GRANT ALL ON SCHEMA clickhouse TO postgres;
GRANT USAGE ON SCHEMA clickhouse TO authenticated;
GRANT USAGE ON SCHEMA clickhouse TO service_role;

-- Create user mapping for authenticated users
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings 
        WHERE srvname = 'clickhouse_server' 
        AND usename = 'postgres'
    ) THEN
        CREATE USER MAPPING FOR postgres
            SERVER clickhouse_server;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_user_mappings 
        WHERE srvname = 'clickhouse_server' 
        AND usename = 'authenticated'
    ) THEN
        CREATE USER MAPPING FOR authenticated
            SERVER clickhouse_server;
    END IF;
END $$;

-- Helper function to execute ClickHouse DDL
CREATE OR REPLACE FUNCTION clickhouse.execute_ddl(query text)
RETURNS void AS $$
BEGIN
    -- This will be implemented once FDW supports DDL passthrough
    -- For now, DDL must be executed directly on ClickHouse
    RAISE NOTICE 'ClickHouse DDL: %', query;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to insert analytics events
CREATE OR REPLACE FUNCTION clickhouse.insert_event(
    event_type text,
    user_id uuid,
    properties jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid AS $$
DECLARE
    event_id uuid := gen_random_uuid();
BEGIN
    -- Insert will be handled via foreign table once created
    -- For now, return the generated event ID
    RETURN event_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function for time-series queries
CREATE OR REPLACE FUNCTION clickhouse.query_metrics(
    metric_name text,
    start_time timestamp DEFAULT now() - interval '1 hour',
    end_time timestamp DEFAULT now(),
    granularity text DEFAULT '1 minute'
)
RETURNS TABLE(time timestamp, value numeric) AS $$
BEGIN
    -- Placeholder for metric queries
    -- Will query from foreign tables once created
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: Foreign tables will be created after ClickHouse tables are set up
-- This is a placeholder for the foreign table definitions

-- Grant permissions on helper functions
GRANT EXECUTE ON FUNCTION clickhouse.execute_ddl(text) TO postgres;
GRANT EXECUTE ON FUNCTION clickhouse.insert_event(text, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION clickhouse.query_metrics(text, timestamp, timestamp, text) TO authenticated;

-- Create a view to check ClickHouse connection status
CREATE OR REPLACE VIEW clickhouse.connection_status AS
SELECT 
    'clickhouse_server' as server_name,
    fs.srvname as foreign_server,
    fs.srvoptions as options,
    current_timestamp as checked_at
FROM pg_foreign_server fs
WHERE fs.srvname = 'clickhouse_server';

GRANT SELECT ON clickhouse.connection_status TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'ClickHouse FDW setup completed successfully';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Start ClickHouse container';
    RAISE NOTICE '2. Create ClickHouse tables';
    RAISE NOTICE '3. Create corresponding foreign tables';
END $$;
