import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

// P1: Strip console.log/error/warn in production builds.
// PENTING: jangan MENGHAPUS keseluruhan panggilan dengan regex. Jika call-nya
// jadi if-body tanpa kurung kurawal (mis. `if (!x) console.warn(...)`),
// penghapusan membuat STATEMENT BERIKUTNYA menjadi if-body — bug prod
// 2026-09-12: DynamicRoutes.fetchAllRouteConfig kehilangan return-nya dan
// mengembalikan undefined → crash `routes.find`. Solusi aman: ganti prefix
// `console.xxx(` dengan `void(` — seimbang di posisi mana pun, tanpa perlu
// match kurung tutup (nested parens tidak jadi masalah).
function stripConsole() {
  return {
    name: 'strip-console',
    enforce: 'post',
    transform(code, id) {
      if (id.includes('node_modules') || !id.match(/\.(js|jsx|ts|tsx)$/)) return null;
      if (process.env.NODE_ENV !== 'production') return null;
      // Neuter console.log/warn/info/error: prefix → `void(`. Hasil:
      // `if (!x) void(args);` — valid di if-body, preseden aman untuk
      // short-circuit (`a && void(b)`), dan tetap menghasilkan undefined
      // seperti console call asli. Kurung tutup call asli menutup `void(`.
      const stripped = code.replace(/\bconsole\.(?:log|warn|info|error)\s*\(/g, 'void(');
      return { code: stripped, map: null };
    },
  };
}

export default defineConfig({
  plugins: [react(), stripConsole()],
  publicDir: 'public',
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
    // Paksa satu instance React/react-router di seluruh app. Tanpa ini,
    // lazy-loaded pages (DynamicRoutes) bisa mendapat salinan react-router-dom
    // yang berbeda dari shell app → "Invalid hook call" / useContext null.
    dedupe: ['react', 'react-dom', 'react-router', 'react-router-dom'],
    extensions: ['.js', '.jsx', '.ts', '.tsx', '.json'],
  },
  optimizeDeps: {
    // Pre-bundle router + react agar semua modul memakai instance yang sama.
    include: ['react', 'react-dom', 'react-router', 'react-router-dom'],
  },
  server: {
    port: 5173,
    open: true,
  },
  build: {
    outDir: 'dist',
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('react-dom') || id.includes('react-router-dom') || id.includes('scheduler')) {
              return 'vendor';
            }
          }
        },
      },
    },
  },
});
