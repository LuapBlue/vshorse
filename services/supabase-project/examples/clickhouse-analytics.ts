// clickhouse-analytics.ts
// Example of using ClickHouse for analytics with Supabase

import { createClient } from '@supabase/supabase-js';

// Type definitions for analytics
interface AnalyticsEvent {
  eventId?: string;
  eventType: string;
  userId: string;
  properties?: Record<string, any>;
  createdAt?: Date;
}

interface MetricData {
  metricName: string;
  value: number;
  tags?: Record<string, string>;
  timestamp?: Date;
}

interface QueryOptions {
  startTime?: Date;
  endTime?: Date;
  granularity?: '1 minute' | '5 minutes' | '1 hour' | '1 day';
}

// Analytics client class
export class ClickHouseAnalytics {
  private supabase: any;

  constructor(supabaseUrl: string, supabaseKey: string) {
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }

  // Track an analytics event
  async trackEvent(event: AnalyticsEvent): Promise<void> {
    try {
      const { data, error } = await this.supabase.rpc('insert_event', {
        event_type: event.eventType,
        user_id: event.userId,
        properties: event.properties || {}
      });

      if (error) throw error;
      console.log('Event tracked:', data);
    } catch (error) {
      console.error('Error tracking event:', error);
      throw error;
    }
  }

  // Track a metric
  async trackMetric(metric: MetricData): Promise<void> {
    try {
      // For now, metrics are inserted as events
      // In production, use a dedicated metrics endpoint
      await this.trackEvent({
        eventType: 'metric',
        userId: 'system',
        properties: {
          metricName: metric.metricName,
          value: metric.value,
          tags: metric.tags,
          timestamp: metric.timestamp || new Date()
        }
      });
    } catch (error) {
      console.error('Error tracking metric:', error);
      throw error;
    }
  }

  // Query metrics from ClickHouse
  async queryMetrics(
    metricName: string,
    options: QueryOptions = {}
  ): Promise<Array<{ time: Date; value: number }>> {
    try {
      const { data, error } = await this.supabase.rpc('query_metrics', {
        metric_name: metricName,
        start_time: options.startTime || new Date(Date.now() - 3600000), // 1 hour ago
        end_time: options.endTime || new Date(),
        granularity: options.granularity || '1 minute'
      });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error querying metrics:', error);
      throw error;
    }
  }

  // Get user analytics summary
  async getUserAnalytics(userId: string): Promise<any> {
    try {
      // Direct query to ClickHouse via PostgreSQL FDW
      const { data, error } = await this.supabase
        .from('clickhouse.user_analytics')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error getting user analytics:', error);
      throw error;
    }
  }

  // Get event count by type
  async getEventCounts(
    startTime: Date,
    endTime: Date
  ): Promise<Array<{ eventType: string; count: number }>> {
    try {
      const query = `
        SELECT event_type, COUNT(*) as count
        FROM clickhouse.events
        WHERE created_at BETWEEN $1 AND $2
        GROUP BY event_type
        ORDER BY count DESC
      `;

      const { data, error } = await this.supabase.rpc('raw_query', {
        query,
        params: [startTime, endTime]
      });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error getting event counts:', error);
      throw error;
    }
  }
}

// Usage examples
async function exampleUsage() {
  const analytics = new ClickHouseAnalytics(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!
  );

  // Track a page view
  await analytics.trackEvent({
    eventType: 'page_view',
    userId: 'user-123',
    properties: {
      page: '/dashboard',
      referrer: 'https://google.com'
    }
  });

  // Track a metric
  await analytics.trackMetric({
    metricName: 'api_response_time',
    value: 125.5,
    tags: {
      endpoint: '/api/users',
      method: 'GET'
    }
  });

  // Query metrics
  const metrics = await analytics.queryMetrics('api_response_time', {
    startTime: new Date(Date.now() - 86400000), // 24 hours ago
    granularity: '1 hour'
  });
  console.log('API response times:', metrics);

  // Get event counts
  const eventCounts = await analytics.getEventCounts(
    new Date(Date.now() - 86400000),
    new Date()
  );
  console.log('Event counts:', eventCounts);

  // Get user analytics
  const userStats = await analytics.getUserAnalytics('user-123');
  console.log('User stats:', userStats);
}

// Export for use in other modules
export { AnalyticsEvent, MetricData, QueryOptions };
