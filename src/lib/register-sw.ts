/**
 * Registrasi PWA Service Worker.
 * Dipindah dari inline <script> index.html agar CSP script-src bisa tanpa 'unsafe-inline'.
 * PwaUpdater hanya menangani notifikasi update — registrasi tetap di sini.
 */
if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').then(
      (reg) => { /* SW registered */ },
      (err) => { /* SW registration failed — non-critical */ },
    );
  });
}
