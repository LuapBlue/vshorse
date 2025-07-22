-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS wrappers WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgsodium WITH SCHEMA extensions;

-- Enable Vault (if not already enabled)
CREATE SCHEMA IF NOT EXISTS vault;

-- Create the Redis Foreign Data Wrapper
CREATE FOREIGN DATA WRAPPER IF NOT EXISTS redis_wrapper 
  HANDLER redis_fdw_handler 
  VALIDATOR redis_fdw_validator;

-- Store Redis connection URL in Vault
-- Note: Replace 'redisSecurePassword123!' with your actual Redis password
DO $$
DECLARE
  redis_key_id uuid;
BEGIN
  -- Store Redis connection URL in Vault
  SELECT vault.create_secret(
    'redis://:redisSecurePassword123!@redis:6379/0',
    'redis_connection',
    'Redis connection URL for Supabase'
  ) INTO redis_key_id;
  
  -- Output the key ID for reference
  RAISE NOTICE 'Redis connection stored with key_id: %', redis_key_id;
END $$;

-- Create Redis server using the stored credentials
-- Note: You'll need to replace <key_ID> with the actual key_id from above
CREATE SERVER IF NOT EXISTS redis_server 
  FOREIGN DATA WRAPPER redis_wrapper 
  OPTIONS (
    conn_url_id '<key_ID>' -- Replace with actual key_id
  );

-- Create schema for Redis foreign tables
CREATE SCHEMA IF NOT EXISTS redis;

-- Grant necessary permissions
GRANT USAGE ON FOREIGN DATA WRAPPER redis_wrapper TO postgres;
GRANT USAGE ON FOREIGN SERVER redis_server TO postgres;
GRANT ALL ON SCHEMA redis TO postgres;

-- Example: Create a foreign table for app configuration (similar to Infisical usage)
CREATE FOREIGN TABLE IF NOT EXISTS redis.app_config (
  key text,
  value text
) SERVER redis_server OPTIONS (
  src_type 'hash',
  src_key 'app:config'
);

-- Example: Create a foreign table for environment variables
CREATE FOREIGN TABLE IF NOT EXISTS redis.env_vars (
  key text,
  value text  
) SERVER redis_server OPTIONS (
  src_type 'hash',
  src_key 'env:vars'
);

-- Create helper functions for easy secret management
CREATE OR REPLACE FUNCTION vault.get_secret(secret_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  secret_value text;
BEGIN
  SELECT decrypted_secret INTO secret_value
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
  -- Check if secret already exists
  SELECT id INTO key_id
  FROM vault.secrets
  WHERE name = secret_name
  LIMIT 1;
  
  IF key_id IS NOT NULL THEN
    -- Update existing secret
    UPDATE vault.secrets
    SET secret = secret_value,
        description = COALESCE(secret_description, description),
        updated_at = now()
    WHERE id = key_id;
  ELSE
    -- Create new secret
    key_id := vault.create_secret(
      secret_value,
      secret_name,
      secret_description
    );
  END IF;
  
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
  decrypted_secret as value,
  'vault' as source
FROM vault.secrets
WHERE name LIKE 'APP_%';

-- Grant permissions on the view
GRANT SELECT ON app_configuration TO postgres, anon, authenticated;
