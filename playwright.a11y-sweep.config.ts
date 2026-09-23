import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

// Sumber env yang sama dengan config utama (VITE_SUPABASE_URL + kredensial E2E).
dotenv.config({ path: '.env.local' });

/**
 * playwright.a11y-sweep.config.ts — config untuk suite sweep a11y penuh (OPS-09).
 *
 * Terpisah dari playwright.a11y.config.ts karena testDir di sana hardcoded
 * './tests/a11y' (hanya spec 6 halaman) — sweep penuh tinggal di
 * tests/a11y-sweep/ agar `npm run test:a11y` tetap cepat (~1.5 menit) dan
 * sweep 154 halaman hanya jalan lewat `npm run test:a11y:full`.
 */
export default defineConfig({
  testDir: './tests/a11y-sweep',
  timeout: 90000,
  // Alur login auth (RPC + OTP) sesekali flake di jaringan lokal — 1 retry,
  // selaras dengan playwright.a11y.config.ts.
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
  outputDir: 'test-results/a11y-sweep/',
});
