-- First check existing extensions
-- Extensions already installed: wrappers, supabase_vault

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

-- Store Redis connection URL in Vault using vault schema
DO $$
DECLARE
  redis_key_id uuid;
BEGIN
  -- Store Redis connection URL in Vault
  INSERT INTO vault.secrets (secret, name, description)
  VALUES (
    vault.encrypt('redis://:redisSecurePassword123!@redis:6379/0'::text, null, null),
    'redis_connection',
    'Redis connection URL for Supabase'
  )
  ON CONFLICT (name) DO UPDATE
  SET secret = EXCLUDED.secret,
      description = EXCLUDED.description
  RETURNING id INTO redis_key_id;
  
  -- Output the key ID for reference
  RAISE NOTICE 'Redis connection stored with key_id: %', redis_key_id;
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
  END IF;
END $$;

-- Create schema for Redis foreign tables
CREATE SCHEMA IF NOT EXISTS redis;

-- Grant necessary permissions
GRANT USAGE ON FOREIGN DATA WRAPPER redis_wrapper TO postgres;
GRANT USAGE ON FOREIGN SERVER redis_server TO postgres;
GRANT ALL ON SCHEMA redis TO postgres;

-- Create foreign tables for app configuration (similar to Infisical usage)
DO $$
BEGIN
  -- Drop existing foreign tables if they exist
  DROP FOREIGN TABLE IF EXISTS redis.app_config;
  DROP FOREIGN TABLE IF EXISTS redis.env_vars;
  
  -- Create foreign table for app configuration
  CREATE FOREIGN TABLE redis.app_config (
    key text,
    value text
  ) SERVER redis_server OPTIONS (
    src_type 'hash',
    src_key 'app:config'
  );
  
  -- Create foreign table for environment variables
  CREATE FOREIGN TABLE redis.env_vars (
    key text,
    value text  
  ) SERVER redis_server OPTIONS (
    src_type 'hash',
    src_key 'env:vars'
  );
END $$;

-- Create helper functions for easy secret management using vault schema
CREATE OR REPLACE FUNCTION vault.get_secret(secret_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  secret_value text;
BEGIN
  SELECT vault.decrypt(secret, null, null) INTO secret_value
  FROM vault.secrets
  WHERE name = secret_name
  LIMIT 1;
  
  RETURN secret_value;
END;
$$;

CREATE OR REPLACE FUNCTION vault.set_secret(
  secret_name text,
  secret_value text,
  secret_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  key_id uuid;
BEGIN
  -- Insert or update the secret
  INSERT INTO vault.secrets (secret, name, description)
  VALUES (
    vault.encrypt(secret_value::text, null, null),
    secret_name,
    secret_description
  )
  ON CONFLICT (name) DO UPDATE
  SET secret = vault.encrypt(secret_value::text, null, null),
      description = COALESCE(secret_description, vault.secrets.description)
  RETURNING id INTO key_id;
  
  RETURN key_id;
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
  vault.decrypt(secret, null, null) as value,
  'vault' as source
FROM vault.secrets
WHERE name LIKE 'APP_%';

-- Grant permissions on the view
GRANT SELECT ON app_configuration TO postgres, anon, authenticated;
