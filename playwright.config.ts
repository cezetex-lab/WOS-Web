import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

// Load .env.local so VITE_SUPABASE_URL is available to the E2E mock helper.
dotenv.config({ path: '.env.local' });

export default defineConfig({
  testDir: './tests/e2e',
  // Generous timeout: cold Vite compiles the import graph lazily per page.
  timeout: 60000,
  retries: 1,
  expect: {
    timeout: 10000,
  },
  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
  webServer: {
    command: 'npm run dev',
    port: 5173,
    reuseExistingServer: true,
    // Cold Vite start on this project (Windows, large import graph) needs ~45s.
    timeout: 120000,
  },
});