/**
 * Error suppressor — menyembunyikan warning browser yang tidak dapat ditindaklanjuti.
 * Dipindah dari inline <script> index.html agar CSP script-src bisa tanpa 'unsafe-inline'.
 * JANGAN tambah pola suppress baru di sini — menyembunyikan bug asli.
 */
if (typeof window !== 'undefined') {
  window.addEventListener('error', (e: ErrorEvent) => {
    // Suppress web-vitals startTime TypeError (browser API issue)
    if (e.message && e.message.includes('startTime')) { e.preventDefault(); return; }
    // Suppress rolldown preload unused warnings
    if (e.message && e.message.includes('preloaded using link preload')) { e.preventDefault(); }
  });
}
