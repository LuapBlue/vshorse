import { test, expect } from '@playwright/test';

test.describe('Supabase API Tests', () => {
  test('should return health status from Supabase', async ({ request }) => {
    const response = await request.get('/');
    expect(response.ok()).toBeTruthy();
  });

  test('should access Socket.io health endpoint', async ({ request }) => {
    const response = await request.get('http://localhost:3020/health');
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('status', 'healthy');
  });

  test('should access Trigger.dev webapp', async ({ page }) => {
    await page.goto('http://localhost:8031');
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Check if we're on the Trigger.dev page
    const title = await page.title();
    expect(title).toBeTruthy();
  });
});

test.describe('VSCode Server Tests', () => {
  test('should access VSCode server', async ({ page }) => {
    await page.goto('http://localhost:8444');
    
    // VSCode might redirect or show a login page
    await page.waitForLoadState('networkidle');
    
    // Check that we get some response
    const url = page.url();
    expect(url).toContain('localhost:8444');
  });
});
