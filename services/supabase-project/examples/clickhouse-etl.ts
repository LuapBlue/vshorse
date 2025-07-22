// clickhouse-etl.ts
// Example ETL pipeline for batch processing data to ClickHouse

import { Queue, Worker, Job } from 'bullmq';
import { createClient } from '@supabase/supabase-js';

// Type definitions
interface BatchEvent {
  events: Array<{
    eventType: string;
    userId: string;
    properties: Record<string, any>;
    timestamp: Date;
  }>;
}

interface ETLJobData {
  source: 'postgres' | 'logs' | 'metrics';
  batchSize: number;
  startTime: Date;
  endTime: Date;
}

interface ETLResult {
  processed: number;
  failed: number;
  duration: number;
}

// ETL Pipeline class
export class ClickHouseETL {
  private queue: Queue;
  private supabase: any;
  private redisConnection: any;

  constructor(
    supabaseUrl: string,
    supabaseKey: string,
    redisConfig: { host: string; port: number }
  ) {
    this.supabase = createClient(supabaseUrl, supabaseKey);
    this.redisConnection = {
      host: redisConfig.host,
      port: redisConfig.port
    };
    
    // Initialize queue
    this.queue = new Queue('clickhouse-etl', {
      connection: this.redisConnection
    });
  }

  // Start ETL worker
  startWorker(): void {
    const worker = new Worker(
      'clickhouse-etl',
      async (job: Job<ETLJobData>) => {
        return await this.processETLJob(job);
      },
      {
        connection: this.redisConnection,
        concurrency: 2
      }
    );

    worker.on('completed', (job, result) => {
      console.log(`ETL job ${job.id} completed:`, result);
    });

    worker.on('failed', (job, error) => {
      console.error(`ETL job ${job?.id} failed:`, error);
    });
  }

  // Process ETL job
  private async processETLJob(job: Job<ETLJobData>): Promise<ETLResult> {
    const startTime = Date.now();
    const { source, batchSize, startTime: dataStartTime, endTime: dataEndTime } = job.data;
    
    let processed = 0;
    let failed = 0;

    try {
      switch (source) {
        case 'postgres':
          const result = await this.etlFromPostgres(dataStartTime, dataEndTime, batchSize);
          processed = result.processed;
          failed = result.failed;
          break;
          
        case 'logs':
          // Process application logs
          await this.etlFromLogs(dataStartTime, dataEndTime, batchSize);
          break;
          
        case 'metrics':
          // Process metrics data
          await this.etlFromMetrics(dataStartTime, dataEndTime, batchSize);
          break;
      }

      const duration = Date.now() - startTime;
      return { processed, failed, duration };
    } catch (error) {
      console.error('ETL job error:', error);
      throw error;
    }
  }

  // ETL from PostgreSQL to ClickHouse
  private async etlFromPostgres(
    startTime: Date,
    endTime: Date,
    batchSize: number
  ): Promise<{ processed: number; failed: number }> {
    let processed = 0;
    let failed = 0;
    let offset = 0;
    
    while (true) {
      // Fetch batch from PostgreSQL
      const { data: events, error } = await this.supabase
        .from('events')
        .select('*')
        .gte('created_at', startTime.toISOString())
        .lte('created_at', endTime.toISOString())
        .range(offset, offset + batchSize - 1);
      
      if (error) {
        console.error('Error fetching events:', error);
        break;
      }
      
      if (!events || events.length === 0) break;
      
      // Insert batch into ClickHouse
      try {
        await this.insertBatchToClickHouse(events);
        processed += events.length;
      } catch (error) {
        failed += events.length;
        console.error('Batch insert failed:', error);
      }
      
      offset += batchSize;
    }
    
    return { processed, failed };
  }

  // Insert batch to ClickHouse
  private async insertBatchToClickHouse(events: any[]): Promise<void> {
    // Convert events to ClickHouse format
    const clickhouseData = events.map(event => ({
      event_id: event.id,
      event_type: event.type,
      user_id: event.user_id,
      properties: JSON.stringify(event.properties),
      created_at: event.created_at
    }));
    
    // Use Supabase RPC to insert via FDW
    const { error } = await this.supabase.rpc('clickhouse_batch_insert', {
      table_name: 'events',
      data: clickhouseData
    });
    
    if (error) throw error;
  }

  // Placeholder for logs ETL
  private async etlFromLogs(startTime: Date, endTime: Date, batchSize: number): Promise<void> {
    console.log('ETL from logs not implemented yet');
  }

  // Placeholder for metrics ETL
  private async etlFromMetrics(startTime: Date, endTime: Date, batchSize: number): Promise<void> {
    console.log('ETL from metrics not implemented yet');
  }

  // Schedule ETL job
  async scheduleETL(jobData: ETLJobData): Promise<string> {
    const job = await this.queue.add('etl-job', jobData, {
      delay: 0,
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 2000
      }
    });
    
    return job.id || 'unknown';
  }

  // Get ETL job status
  async getJobStatus(jobId: string): Promise<any> {
    const job = await this.queue.getJob(jobId);
    if (!job) return null;
    
    return {
      id: job.id,
      status: await job.getState(),
      progress: job.progress,
      data: job.data,
      result: job.returnvalue
    };
  }
}

// Usage example
async function exampleETLUsage() {
  const etl = new ClickHouseETL(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    {
      host: 'localhost',
      port: 6379
    }
  );

  // Start the worker
  etl.startWorker();

  // Schedule an ETL job
  const jobId = await etl.scheduleETL({
    source: 'postgres',
    batchSize: 1000,
    startTime: new Date(Date.now() - 86400000), // 24 hours ago
    endTime: new Date()
  });

  console.log('ETL job scheduled:', jobId);

  // Check job status
  const status = await etl.getJobStatus(jobId);
  console.log('Job status:', status);
}

// Export for use in other modules
export { ETLJobData, ETLResult };
