import { defineConfig } from 'vitest/config';
import { availableParallelism } from 'node:os';
import path from 'path';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    css: false,
    include: ['tests/**/*.test.{ts,tsx}'],
    // pool=threads: default 'forks' spawns a full Node process per worker —
    // on Windows aangenaam flaky ("Timeout waiting for worker to respond")
    // onder resource contention. Threads = 1 process, stabiel.
    pool: 'threads',
    // Batas worker. Vitest memakai timeout keras 60s untuk pool runner-nya
    // (`START_TIMEOUT` di vitest/dist chunks — tidak bisa dikonfigurasi), dan
    // default-nya menyalakan satu worker per core. Di mesin 12 core itu berarti
    // 12 worker booting bersamaan (jsdom + seluruh graph modul) → pool runner
    // kehabisan waktu dan semua berkas yang ikut worker itu gagal dengan
    // "Failed to start threads worker". Suite ini kecil (belasan berkas), jadi
    // 4 worker sudah lebih dari cukup; boot jadi tidak berebut CPU.
    maxWorkers: Math.max(1, Math.min(4, availableParallelism() - 1)),
    coverage: {
      provider: 'v8',
      reporter: ['text', 'text-summary'],
      include: ['src/lib/**', 'src/hooks/**'],
      exclude: ['node_modules/', 'tests/'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
});
