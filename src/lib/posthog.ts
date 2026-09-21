import { getSession } from './supabase-browser';
import type { UserSession } from '@/types';

// PostHog — product analytics (manual events only)
// OPS-03b (2026-09-21): posthog-js TIDAK lagi di-import statis di sini — modul ini
// kini loader tipis. Init dijadwalkan SETELAH startup (requestIdleCallback, timeout
// 3 dtk) dan posthog-js diambil via dynamic import, sehingga analytics tidak pernah
// memblok render pertama / main bundle (sebelumnya: import statis di main.tsx membuat
// seluruh posthog-js masuk chunk awal).
// Free tier: 1M events/month + 5K session recordings
const POSTHOG_KEY = import.meta.env.VITE_POSTHOG_KEY;
const POSTHOG_HOST = import.meta.env.VITE_POSTHOG_HOST || 'https://us.i.posthog.com';

let initPromise: Promise<void> | null = null;

/** Init posthog (idempoten, lazy). Aman dipanggil berkali-kali. */
export function initPosthog(): Promise<void> {
  if (initPromise) return initPromise;
  initPromise = (async () => {
    if (!POSTHOG_KEY) return;
    const { default: posthog } = await import('posthog-js');
    posthog.init(POSTHOG_KEY, {
      api_host: POSTHOG_HOST,
      // P0 FIX: All autocapture DISABLED to protect free tier
      autocapture: false,
      capture_pageview: false,    // manual only
      capture_pageleave: false,   // manual only
      capture_console_errors: false,

      // Session recording DISABLED (5K/month limit — too risky)
      // Cukup tidak mendaftarkan session recording — default mati, jangan diaktifkan.

      // Performance
      loaded: (ph: any) => {
        const session = (getSession() || {}) as UserSession;
        if (session.nrp) {
          ph.identify(session.nrp, { role: session.role });
        }
      },

      // Persistence
      persistence: 'localStorage',
      persistence_name: 'insightwos_posthog',

      // Sanitize sensitive data
      sanitize_properties: (props: any) => {
        if (props.$set) {
          delete props.$set.email;
          delete props.$set.password;
          delete props.$set.bank_account;
          delete props.$set.salary;
        }
        return props;
      },
      // Config object berisi kunci legacy (capture_console_errors, session_recording)
      // yang tidak ada di tipe PostHogConfig versi terpasang. Runtime posthog-js tetap
      // memakainya; `as any` hanya untuk memenuhi type-checker tanpa mengubah perilaku.
    } as any);
    (window as any).posthog = posthog;
  })().catch(() => {
    // Analytics tidak boleh menggagalkan app (mis. jaringan blokir posthog).
  });
  return initPromise;
}

// OPS-03b: jadwalkan init SETELAH startup idle — tidak memblok render pertama.
// Dipanggil dari sini (evaluasi module, dipicu import side-effect main.tsx yang
// sudah ada) supaya titik pemanggilan lama tidak perlu berubah.
if (typeof window !== 'undefined') {
  const schedule = (cb: () => void): void => {
    const w = window as any;
    if (typeof w.requestIdleCallback === 'function') w.requestIdleCallback(cb, { timeout: 3000 });
    else setTimeout(cb, 1500);
  };
  schedule(() => { void initPosthog(); });
}

// ── Manual Event Tracking (ONLY critical business events) ──
// Semua helper no-op aman bila posthog belum ter-load (init deferred): event yang
// terjadi sebelum idle-init di-drop — perilaku analytics manual-only, tidak boleh
// memengaruhi jalur bisnis. (Dulu: memakai instance posthog yang mengantre.)

export const track = (event: string, properties: Record<string, any> = {}) => {
  (window as any).posthog?.capture(event, properties);
};

export const isFeatureEnabled = (flag: string): boolean => {
  try {
    return (window as any).posthog?.isFeatureEnabled?.(flag) === true;
  } catch {
    return false;
  }
};

export const identifyUser = (nrp: string, properties: Record<string, any> = {}) => {
  try {
    (window as any).posthog?.identify?.(nrp, properties);
  } catch {}
};

export const resetUser = () => {
  try {
    (window as any).posthog?.reset?.();
  } catch {}
};

// ── Custom Event Tracking ──
export function trackPageView(pageName: string, properties: Record<string, any> = {}): void {
  try {
    (window as any).posthog?.capture('page_viewed', { page: pageName, ...properties });
  } catch {}
}

export function trackRpcCall(rpcName: string, success: boolean, duration: number): void {
  try {
    (window as any).posthog?.capture('rpc_called', { rpc: rpcName, success, duration_ms: duration });
  } catch {}
}

export function trackUserAction(action: string, target: string, properties: Record<string, any> = {}): void {
  try {
    (window as any).posthog?.capture('user_action', { action, target, ...properties });
  } catch {}
}

export function trackError(error: Error, context: Record<string, any> = {}): void {
  try {
    (window as any).posthog?.capture('error_occurred', { error: error.message || String(error), ...context });
  } catch {}
}
