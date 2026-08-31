import posthog from 'posthog-js';

// PostHog — product analytics, session recording, error tracking, feature flags
// Free tier: 1M events/month + 5K session recordings
const POSTHOG_KEY = import.meta.env.VITE_POSTHOG_KEY;
const POSTHOG_HOST = import.meta.env.VITE_POSTHOG_HOST || 'https://us.i.posthog.com';

if (POSTHOG_KEY && import.meta.env.PROD) {
  posthog.init(POSTHOG_KEY, {
    api_host: POSTHOG_HOST,
    // Auto-capture
    autocapture: true,
    capture_pageview: true,
    capture_pageleave: true,
    capture_console_errors: true,   // ← error tracking built-in!
    
    // Session recording (free tier: 5K/month)
    session_recording: {
      recordCrossOriginIframes: false,
      maskTextSelector: '.ph-no-capture, input[type="password"]',
    },
    
    // Performance
    loaded: (ph) => {
      // Identify user on login
      const nrp = sessionStorage.getItem('nrp');
      const role = sessionStorage.getItem('role');
      if (nrp) {
        ph.identify(nrp, { role });
      }
    },
    
    // Persistence
    persistence: 'localStorage',
    persistence_name: 'insightwos_posthog',
    
    // Privacy — don't record password fields
    sanitize_properties: (props) => {
      // Remove sensitive data from events
      if (props.$set) {
        delete props.$set.email;
        delete props.$set.password;
      }
      return props;
    },
  });
}

export default posthog;

// Utility: track custom events
export const track = (event, properties = {}) => {
  if (import.meta.env.PROD && POSTHOG_KEY) {
    posthog.capture(event, properties);
  }
};

// Utility: feature flags
export const isFeatureEnabled = (flag) => {
  if (!POSTHOG_KEY) return false;
  return posthog.isFeatureEnabled(flag);
};

// Utility: identify user after login
export const identifyUser = (nrp, properties = {}) => {
  if (import.meta.env.PROD && POSTHOG_KEY) {
    posthog.identify(nrp, properties);
  }
};

// Utility: reset on logout
export const resetUser = () => {
  if (import.meta.env.PROD && POSTHOG_KEY) {
    posthog.reset();
  }
};
