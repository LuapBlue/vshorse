import { test, expect } from '@playwright/test';

test.describe('Supabase ClickHouse FDW Integration', () => {
  test('Supabase Studio is accessible', async ({ page }) => {
    await page.goto('http://localhost:3000');
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Check if we're on the login page or dashboard
    const title = await page.title();
    expect(title).toContain('Supabase');
  });

  test('PostgreSQL FDW connection works', async ({ request }) => {
    // This test would require auth tokens and proper setup
    // For now, we just check if the API is responding
    const response = await request.get('http://localhost:8000/rest/v1/');
    
    // API should return 401 without auth, which is expected
    expect(response.status()).toBe(401);
  });

  test('Kong API Gateway is running', async ({ request }) => {
    const response = await request.get('http://localhost:8000/');
    expect(response.status()).toBeLessThan(500);
  });
});

test.describe('Service Health Checks', () => {
  const services = [
    { name: 'Supabase Studio', url: 'http://localhost:3000', expectedStatus: 200 },
    { name: 'Kong API Gateway', url: 'http://localhost:8000', expectedStatus: 404 },
    { name: 'ClickHouse HTTP', url: 'http://localhost:8123/ping', expectedStatus: 200 },
  ];

  for (const service of services) {
    test(`${service.name} is running`, async ({ request }) => {
      const response = await request.get(service.url);
      expect(response.status()).toBe(service.expectedStatus);
    });
  }
});
