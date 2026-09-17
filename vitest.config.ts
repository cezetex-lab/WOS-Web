import { defineConfig } from 'vitest/config';
import { availableParallelism } from 'node:os';
import path from 'path';

/**
 * Berkas yang BENAR-BENAR butuh DOM (jsdom + matcher `@testing-library/jest-dom`).
 *
 * Ini daftar putih, jadi default-nya adalah lingkungan `node` yang murah: menambah
 * berkas test baru di `tests/unit/` otomatis jalan tanpa jsdom. Kalau berkas baru
 * menyentuh `window`/`localStorage` dan gagal dengan "window is not defined",
 * tambahkan di sini — jangan dibalik jadi default jsdom (itu justru yang membuat
 * suite ini lambat: boot jsdom + impor jest-dom per berkas, padahal test-nya
 * sendiri hanya butuh puluhan milidetik).
 *
 * Sisa berkas di `tests/unit/` tidak perlu didaftarkan karena tidak menyentuh DOM,
 * dan beberapa di antaranya juga mendeklarasikan `// @vitest-environment node`
 * secara eksplisit sebagai pengaman ganda.
 */
const DOM_TESTS = [
  'tests/component/**/*.test.{ts,tsx}',
  'tests/unit/lib-modules.test.ts',
  'tests/unit/menu-builder.test.ts',
  'tests/unit/rpc-contract.test.ts',
  'tests/unit/session.test.ts',
  'tests/unit/supabase-browser.test.ts',
];

// Batas worker per project. Vitest memakai timeout keras 60s untuk pool runner-nya
// (`START_TIMEOUT` di vitest/dist — tidak bisa dikonfigurasi), dan default-nya
// menyalakan satu worker per core. Di mesin 12 core itu berarti belasan worker
// booting bersamaan (jsdom + seluruh graph modul) → pool runner kehabisan waktu
// dan semua berkas yang ikut worker itu gagal dengan "Failed to start threads
// worker". Suite ini kecil, jadi 2 worker per project lebih dari cukup.
const perProjectWorkers = Math.max(1, Math.min(2, availableParallelism() - 1));

export default defineConfig({
  test: {
    globals: true,
    css: false,
    // pool=threads: default 'forks' spawns a full Node process per worker —
    // on Windows aangenaam flaky onder resource contention. Threads = stabiel.
    pool: 'threads',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'text-summary'],
      include: ['src/lib/**', 'src/hooks/**'],
      exclude: ['node_modules/', 'tests/'],
    },
    projects: [
      {
        // `extends: true` → mewarisi resolve.alias dan opsi test di atas.
        extends: true,
        test: {
          name: 'jsdom',
          environment: 'jsdom',
          setupFiles: ['./tests/setup.ts'],
          include: DOM_TESTS,
          maxWorkers: perProjectWorkers,
        },
      },
      {
        extends: true,
        test: {
          name: 'node',
          environment: 'node',
          include: ['tests/**/*.test.{ts,tsx}'],
          exclude: [...DOM_TESTS, '**/node_modules/**'],
          maxWorkers: perProjectWorkers,
        },
      },
    ],
  },
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
});
