import { test, expect } from '@playwright/test';

test.describe('ClickHouse Integration', () => {
  test('ClickHouse HTTP interface is accessible', async ({ request }) => {
    const response = await request.get('http://localhost:8123/ping');
    expect(response.ok()).toBeTruthy();
    expect(await response.text()).toBe('Ok.\n');
  });

  test('ClickHouse can execute queries', async ({ request }) => {
    const response = await request.get('http://localhost:8123/', {
      params: {
        query: 'SELECT 1 as test'
      },
      headers: {
        'X-ClickHouse-User': process.env.CLICKHOUSE_USER || 'default',
        'X-ClickHouse-Key': process.env.CLICKHOUSE_PASSWORD || ''
      }
    });
    
    expect(response.ok()).toBeTruthy();
    const result = await response.text();
    expect(result.trim()).toBe('1');
  });

  test('Analytics database exists', async ({ request }) => {
    const response = await request.get('http://localhost:8123/', {
      params: {
        query: 'SHOW DATABASES'
      },
      headers: {
        'X-ClickHouse-User': process.env.CLICKHOUSE_USER || 'default',
        'X-ClickHouse-Key': process.env.CLICKHOUSE_PASSWORD || ''
      }
    });
    
    expect(response.ok()).toBeTruthy();
    const databases = await response.text();
    expect(databases).toContain('analytics');
  });
});
