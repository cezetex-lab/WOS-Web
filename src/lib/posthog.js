import posthog from 'posthog-js';

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
    session_recording: {
      enabled: false,
    },
    
    // Performance
    loaded: (ph) => {
      const session = JSON.parse(sessionStorage.getItem('wos_user') || '{}');
      if (session.nrp) {
        ph.identify(session.nrp, { role: session.role });
      }
    },
    
    // Persistence
    persistence: 'localStorage',
    persistence_name: 'insightwos_posthog',
    
    // Sanitize sensitive data
    sanitize_properties: (props) => {
      if (props.$set) {
        delete props.$set.email;
        delete props.$set.password;
        delete props.$set.bank_account;
        delete props.$set.salary;
      }
      return props;
    },
  });
}

export default posthog;

// ── Manual Event Tracking (ONLY critical business events) ──
// Use: track('user_login', { nrp, role }) — NOT for page views or clicks

export const track = (event, properties = {}) => {
  if (POSTHOG_KEY) {
    posthog.capture(event, properties);
  }
};

export const isFeatureEnabled = (flag) => {
  if (!POSTHOG_KEY) return false;
  return posthog.isFeatureEnabled(flag);
};

export const identifyUser = (nrp, properties = {}) => {
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
export function trackPageView(pageName, properties = {}) {
  try {
    window.posthog?.capture('page_viewed', { page: pageName, ...properties });
  } catch {}
}

export function trackRpcCall(rpcName, success, duration) {
  try {
    window.posthog?.capture('rpc_called', { rpc: rpcName, success, duration_ms: duration });
  } catch {}
}

export function trackUserAction(action, target, properties = {}) {
  try {
    window.posthog?.capture('user_action', { action, target, ...properties });
  } catch {}
}

export function trackError(error, context = {}) {
  try {
    window.posthog?.capture('error_occurred', { error: error.message || String(error), ...context });
  } catch {}
}
