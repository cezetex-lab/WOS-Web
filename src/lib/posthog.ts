import { getSession } from './supabase-browser';
import type { UserSession } from '@/types';

import posthog, { type PostHog } from 'posthog-js';

// PostHog — product analytics (manual events only)
// Free tier: 1M events/month + 5K session recordings
const POSTHOG_KEY = import.meta.env.VITE_POSTHOG_KEY;
const POSTHOG_HOST = import.meta.env.VITE_POSTHOG_HOST || 'https://us.i.posthog.com';

if (POSTHOG_KEY) {
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
    loaded: (ph: PostHog) => {
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
}

export default posthog;

// ── Manual Event Tracking (ONLY critical business events) ──
// Use: track('user_login', { nrp, role }) — NOT for page views or clicks

export const track = (event: string, properties: Record<string, any> = {}) => {
  if (POSTHOG_KEY) {
    posthog.capture(event, properties);
  }
};

export const isFeatureEnabled = (flag: string): boolean => {
  if (!POSTHOG_KEY) return false;
  return posthog.isFeatureEnabled(flag) === true;
};

export const identifyUser = (nrp: string, properties: Record<string, any> = {}) => {
  if (POSTHOG_KEY) {
    posthog.identify(nrp, properties);
  }
};

export const resetUser = () => {
  if (POSTHOG_KEY) {
    posthog.reset();
  }
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
