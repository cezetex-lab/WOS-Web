import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

// P1: Strip console.log/error/warn in production builds
function stripConsole() {
  return {
    name: 'strip-console',
    enforce: 'post',
    transform(code, id) {
      if (id.includes('node_modules') || !id.match(/\.(js|jsx|ts|tsx)$/)) return null;
      if (process.env.NODE_ENV !== 'production') return null;
      // Remove console.log, console.warn, console.error, console.info
      const stripped = code
        .replace(/console\.\s*log\s*\([^)]*\)\s*;?/g, '')
        .replace(/console\.\s*warn\s*\([^)]*\)\s*;?/g, '')
        .replace(/console\.\s*error\s*\([^)]*\)\s*;?/g, '')
        .replace(/console\.\s*info\s*\([^)]*\)\s*;?/g, '');
      return { code: stripped, map: null };
    },
  };
}

export default defineConfig({
  plugins: [react(), stripConsole()],
  publicDir: 'public',
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
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
    port: 3000,
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
