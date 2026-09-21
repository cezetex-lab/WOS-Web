import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

// Sumber env yang sama dengan config utama (VITE_SUPABASE_URL + kredensial E2E).
dotenv.config({ path: '.env.local' });

/**
 * playwright.a11y.config.ts — config khusus suite a11y (FASE 3 Stage 1).
 *
 * Alasan file ini ada: playwright.config.ts memakai testDir './tests/e2e',
 * sehingga `npx playwright test tests/a11y/` TANPA --config akan gagal
 * "no tests found". Script test:a11y memakai --config=playwright.a11y.config.ts.
 */
export default defineConfig({
  testDir: './tests/a11y',
  timeout: 90000,
  // Alur login auth (RPC + OTP) sesekali flake di jaringan lokal — 1 retry,
  // selaras dengan playwright.config.ts utama.
  retries: 1,
  expect: { timeout: 10000 },
  use: {
    baseURL: process.env.TEST_BASE_URL || 'http://localhost:5173',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
  webServer: {
    command: 'npm run dev',
    port: 5173,
    reuseExistingServer: true,
    // Cold Vite start di proyek ini (Windows, import graph besar) butuh ~45 dtk.
    timeout: 120000,
  },
  outputDir: 'test-results/a11y/',
});
