// ============================================================
// log-error.js — Error logging helper untuk loader & action RPC
// ============================================================
// console.error (dev) + PostHog trackError (production). Diperlukan
// karena plugin strip-console (vite.config.js) membuang console.*
// di build production — tanpa trackError, kegagalan RPC tidak
// terpantau sama sekali di production.
// PostHog di sini manual-only (tanpa autocapture) dan no-op aman
// bila VITE_POSTHOG_KEY tidak diset.

import { trackError } from './posthog';

export function logError(page, loader, err) {
  const msg = err?.message || String(err);
  console.error(`[${page}:${loader}]`, err);
  trackError(err instanceof Error ? err : new Error(msg), { page, loader });
}

// Factory per halaman: const logError = createPageErrorLogger('Dashboard')
// lalu dipakai: logError('loadData', err)
export function createPageErrorLogger(page) {
  return (loader, err) => logError(page, loader, err);
}
