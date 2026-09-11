import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.js'],
    css: false,
    include: ['tests/**/*.test.{js,jsx,ts,tsx}'],
    // pool=threads: default 'forks' spawns a full Node process per worker —
    // on Windows aangenaam flaky ("Timeout waiting for worker to respond")
    // onder resource contention. Threads = 1 process, stabiel.
    pool: 'threads',
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
