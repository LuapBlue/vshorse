-- Setup Message Queue integration with Supabase
-- This provides monitoring and management capabilities for both RabbitMQ and BullMQ

-- Create schema for message queue data
CREATE SCHEMA IF NOT EXISTS queues;

-- Grant permissions
GRANT ALL ON SCHEMA queues TO postgres;
GRANT USAGE ON SCHEMA queues TO anon, authenticated;

-- Store queue credentials in Vault
DO $$
DECLARE
  rabbitmq_key_id uuid;
  bullmq_key_id uuid;
BEGIN
  -- Store RabbitMQ connection URL
  SELECT vault.create_secret(
    'amqp://rabbitmq:rabbitmq_secure_pass_2025!@rabbitmq:5672/',
    'rabbitmq_connection',
    'RabbitMQ connection URL'
  ) INTO rabbitmq_key_id;
  
  -- Store BullMQ Redis connection (already exists, but add BullMQ-specific)
  SELECT vault.create_secret(
    'redis://:redisSecurePassword123!@redis:6379/1',  -- Use database 1 for BullMQ
    'bullmq_connection',
    'BullMQ Redis connection URL'
  ) INTO bullmq_key_id;
  
  RAISE NOTICE 'RabbitMQ connection stored with key_id: %', rabbitmq_key_id;
  RAISE NOTICE 'BullMQ connection stored with key_id: %', bullmq_key_id;
END $$;

-- Create table to track queue definitions
CREATE TABLE IF NOT EXISTS queues.queue_definitions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  type text NOT NULL CHECK (type IN ('rabbitmq', 'bullmq')),
  config jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create table to track jobs/messages
CREATE TABLE IF NOT EXISTS queues.job_history (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  queue_name text NOT NULL,
  queue_type text NOT NULL CHECK (queue_type IN ('rabbitmq', 'bullmq')),
  job_id text,
  status text NOT NULL CHECK (status IN ('pending', 'active', 'completed', 'failed', 'delayed', 'waiting')),
  data jsonb,
  result jsonb,
  error text,
  created_at timestamptz DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  attempts integer DEFAULT 0
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_job_history_queue_name ON queues.job_history(queue_name);
CREATE INDEX IF NOT EXISTS idx_job_history_status ON queues.job_history(status);
CREATE INDEX IF NOT EXISTS idx_job_history_created_at ON queues.job_history(created_at DESC);

-- Function to register a queue
CREATE OR REPLACE FUNCTION queues.register_queue(
  queue_name text,
  queue_type text,
  queue_config jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  queue_id uuid;
BEGIN
  INSERT INTO queues.queue_definitions (name, type, config)
  VALUES (queue_name, queue_type, queue_config)
  ON CONFLICT (name) DO UPDATE
  SET config = EXCLUDED.config,
      updated_at = now()
  RETURNING id INTO queue_id;
  
  RETURN queue_id;
END;
$$;

-- Function to log job execution
CREATE OR REPLACE FUNCTION queues.log_job(
  p_queue_name text,
  p_queue_type text,
  p_job_id text DEFAULT NULL,
  p_status text DEFAULT 'pending',
  p_data jsonb DEFAULT NULL,
  p_result jsonb DEFAULT NULL,
  p_error text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  job_log_id uuid;
BEGIN
  INSERT INTO queues.job_history (
    queue_name, queue_type, job_id, status, data, result, error
  )
  VALUES (
    p_queue_name, p_queue_type, p_job_id, p_status, p_data, p_result, p_error
  )
  RETURNING id INTO job_log_id;
  
  RETURN job_log_id;
END;
$$;

-- Function to update job status
CREATE OR REPLACE FUNCTION queues.update_job_status(
  p_job_log_id uuid,
  p_status text,
  p_result jsonb DEFAULT NULL,
  p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE queues.job_history
  SET status = p_status,
      result = COALESCE(p_result, result),
      error = COALESCE(p_error, error),
      started_at = CASE 
        WHEN p_status = 'active' AND started_at IS NULL THEN now() 
        ELSE started_at 
      END,
      completed_at = CASE 
        WHEN p_status IN ('completed', 'failed') THEN now() 
        ELSE completed_at 
      END,
      attempts = attempts + CASE WHEN p_status = 'active' THEN 1 ELSE 0 END
  WHERE id = p_job_log_id;
END;
$$;

-- View for queue statistics
CREATE OR REPLACE VIEW queues.queue_stats AS
SELECT 
  queue_name,
  queue_type,
  COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
  COUNT(*) FILTER (WHERE status = 'active') as active_count,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
  COUNT(*) FILTER (WHERE status = 'delayed') as delayed_count,
  COUNT(*) as total_count,
  MAX(created_at) as last_job_created,
  MAX(completed_at) as last_job_completed
FROM queues.job_history
GROUP BY queue_name, queue_type;

-- Grant permissions
GRANT SELECT ON queues.queue_stats TO anon, authenticated;
GRANT ALL ON queues.queue_definitions TO authenticated;
GRANT ALL ON queues.job_history TO authenticated;

-- Helper function to get queue connection details
CREATE OR REPLACE FUNCTION queues.get_connection_url(queue_type text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT decrypted_secret 
  FROM vault.decrypted_secrets 
  WHERE name = CASE 
    WHEN queue_type = 'rabbitmq' THEN 'rabbitmq_connection'
    WHEN queue_type = 'bullmq' THEN 'bullmq_connection'
    ELSE NULL
  END
  LIMIT 1;
$$;

-- Create RabbitMQ management functions
CREATE OR REPLACE FUNCTION queues.rabbitmq_publish(
  exchange text,
  routing_key text,
  message jsonb,
  options jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  job_id uuid;
BEGIN
  -- Log the message
  job_id := queues.log_job(
    p_queue_name := exchange || '.' || routing_key,
    p_queue_type := 'rabbitmq',
    p_status := 'pending',
    p_data := jsonb_build_object(
      'exchange', exchange,
      'routing_key', routing_key,
      'message', message,
      'options', options
    )
  );
  
  -- In a real implementation, this would trigger a webhook or notify a service
  -- For now, we just log it
  
  RETURN job_id;
END;
$$;

-- Create BullMQ management functions
CREATE OR REPLACE FUNCTION queues.bullmq_add_job(
  queue_name text,
  job_name text,
  job_data jsonb,
  job_opts jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  job_id uuid;
BEGIN
  -- Log the job
  job_id := queues.log_job(
    p_queue_name := queue_name,
    p_queue_type := 'bullmq',
    p_job_id := job_name,
    p_status := 'pending',
    p_data := jsonb_build_object(
      'name', job_name,
      'data', job_data,
      'opts', job_opts
    )
  );
  
  -- In a real implementation, this would trigger a webhook or notify a service
  -- For now, we just log it
  
  RETURN job_id;
END;
$$;

-- Register default queues
SELECT queues.register_queue('default', 'bullmq', '{"removeOnComplete": 100, "removeOnFail": 1000}'::jsonb);
SELECT queues.register_queue('emails', 'bullmq', '{"attempts": 3, "backoff": {"type": "exponential", "delay": 2000}}'::jsonb);
SELECT queues.register_queue('notifications', 'rabbitmq', '{"durable": true, "autoDelete": false}'::jsonb);

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Message Queue integration setup completed successfully!';
  RAISE NOTICE 'RabbitMQ Management UI: http://localhost:15672 (user: rabbitmq)';
  RAISE NOTICE 'Bull Board UI: http://localhost:3030';
END $$;
