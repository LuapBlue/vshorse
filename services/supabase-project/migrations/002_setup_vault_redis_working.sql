-- Working with Supabase Vault implementation
-- This script sets up Redis integration with Supabase using the actual vault functions

-- Create the Redis Foreign Data Wrapper
DO $$
BEGIN
    -- Check if redis_wrapper already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_foreign_data_wrapper WHERE fdwname = 'redis_wrapper'
    ) THEN
        CREATE FOREIGN DATA WRAPPER redis_wrapper 
          HANDLER redis_fdw_handler 
          VALIDATOR redis_fdw_validator;
    END IF;
END $$;

-- Store Redis connection URL in Vault (if not already exists)
DO $$
DECLARE
  redis_key_id uuid;
BEGIN
  -- Check if redis_connection already exists
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = 'redis_connection'
  ) THEN
    -- Store Redis connection URL in Vault
    SELECT vault.create_secret(
      'redis://:redisSecurePassword123!@redis:6379/0',
      'redis_connection',
      'Redis connection URL for Supabase'
    ) INTO redis_key_id;
    
    RAISE NOTICE 'Redis connection stored with key_id: %', redis_key_id;
  ELSE
    SELECT id INTO redis_key_id FROM vault.secrets WHERE name = 'redis_connection';
    RAISE NOTICE 'Redis connection already exists with key_id: %', redis_key_id;
  END IF;
END $$;

-- Create Redis server using the stored credentials
DO $$
DECLARE
  redis_key_id uuid;
BEGIN
  -- Get the key_id for redis connection
  SELECT id INTO redis_key_id
  FROM vault.secrets
  WHERE name = 'redis_connection'
  LIMIT 1;
  
  -- Drop existing server if it exists
  DROP SERVER IF EXISTS redis_server CASCADE;
  
  -- Create the server with the key_id
  IF redis_key_id IS NOT NULL THEN
    EXECUTE format('CREATE SERVER redis_server FOREIGN DATA WRAPPER redis_wrapper OPTIONS (conn_url_id ''%s'')', redis_key_id);
    RAISE NOTICE 'Redis server created successfully';
  END IF;
END $$;

-- Create schema for Redis foreign tables
CREATE SCHEMA IF NOT EXISTS redis;

-- Grant necessary permissions
GRANT USAGE ON FOREIGN DATA WRAPPER redis_wrapper TO postgres;
GRANT USAGE ON FOREIGN SERVER redis_server TO postgres;
GRANT ALL ON SCHEMA redis TO postgres;

-- Create foreign tables for app configuration
DO $$
BEGIN
  -- Create foreign table for app configuration
  CREATE FOREIGN TABLE IF NOT EXISTS redis.app_config (
    key text,
    value text
  ) SERVER redis_server OPTIONS (
    src_type 'hash',
    src_key 'app:config'
  );
  
  -- Create foreign table for environment variables
  CREATE FOREIGN TABLE IF NOT EXISTS redis.env_vars (
    key text,
    value text  
  ) SERVER redis_server OPTIONS (
    src_type 'hash',
    src_key 'env:vars'
  );
  
  RAISE NOTICE 'Redis foreign tables created successfully';
END $$;

-- Create helper functions for easy secret management
CREATE OR REPLACE FUNCTION vault.get_secret(secret_name text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT decrypted_secret 
  FROM vault.decrypted_secrets 
  WHERE name = secret_name 
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION vault.set_secret(
  secret_name text,
  secret_value text,
  secret_description text DEFAULT ''
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_id uuid;
  result_id uuid;
BEGIN
  -- Check if secret already exists
  SELECT id INTO existing_id
  FROM vault.secrets
  WHERE name = secret_name
  LIMIT 1;
  
  IF existing_id IS NOT NULL THEN
    -- Update existing secret
    PERFORM vault.update_secret(
      existing_id,
      secret_value,
      secret_name,
      secret_description
    );
    result_id := existing_id;
  ELSE
    -- Create new secret
    result_id := vault.create_secret(
      secret_value,
      secret_name,
      secret_description
    );
  END IF;
  
  RETURN result_id;
END;
$$;

-- Create a view for easy access to app configuration
CREATE OR REPLACE VIEW app_configuration AS
SELECT 
  key,
  value,
  'redis' as source
FROM redis.app_config
UNION ALL
SELECT
  name as key,
  decrypted_secret as value,
  'vault' as source
FROM vault.decrypted_secrets
WHERE name LIKE 'APP_%';

-- Grant permissions on the view
GRANT SELECT ON app_configuration TO postgres, anon, authenticated;

-- Display success message
DO $$
BEGIN
  RAISE NOTICE 'Vault and Redis integration setup completed successfully!';
END $$;
