import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

// Load .env.local so VITE_SUPABASE_URL is available to the E2E mock helper.
dotenv.config({ path: '.env.local' });

export default defineConfig({
  testDir: './tests/e2e',
  // Generous timeout: cold Vite compiles the import graph lazily per page.
  timeout: 90000,
  retries: 1,
  expect: {
    timeout: 20000,
  },
  // 12 CPU → default 6 worker menjadikan Vite dev-server (compile chunk dingin)
  // bottleneck: login mocked time-out 15 dtk → 2 fail + 8 flaky (2026-09-24).
  // 2 worker = stabil tanpa mengubah asersi test.
  workers: 2,
  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    // BATAS AKSI (temuan RUN 4 2026-09-25). Default Playwright: actionTimeout = 0
    // ⇒ `click()`/`fill()` yang tidak bisa dijalankan menunggu SAMPAI test timeout.
    // Terbukti: four-page Dashboard berhasil login (`otpWaits=0`), lalu `logout`
    // menghabiskan 605,9 s (test timeout 600 s) hanya karena tombol Logout lambat
    // bisa diklik → run menjadi 21,3 menit dan muncul 1 fail + 1 flaky.
    // Dengan batas aksi, kegagalan datang cepat (15 s) lalu retry — bukan menggantung.
    actionTimeout: 15000,
    // `page.goto()` tanpa timeout eksplisit juga tidak boleh memakai jatah test penuh.
    navigationTimeout: 45000,
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