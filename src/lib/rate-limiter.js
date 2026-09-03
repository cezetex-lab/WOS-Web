// ============================================================
// rate-limiter.js — Client-side rate limiting for RPC calls
// ============================================================

const rateLimits = {};
const DEFAULT_WINDOW_MS = 60000; // 1 minute
const DEFAULT_MAX_REQUESTS = 30;

/**
 * Check if a function call is rate-limited
 * @param {string} fn - RPC function name
 * @param {number} maxRequests - max calls per window
 * @param {number} windowMs - time window in ms
 * @returns {{ allowed: boolean, retryAfter: number }}
 */
export function checkRateLimit(fn, maxRequests = DEFAULT_MAX_REQUESTS, windowMs = DEFAULT_WINDOW_MS) {
  const now = Date.now();
  
  if (!rateLimits[fn]) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  const entry = rateLimits[fn];

  // Reset window if expired
  if (now - entry.windowStart > windowMs) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  // Increment count
  entry.count++;

  // Check limit
  if (entry.count > maxRequests) {
    const retryAfter = Math.ceil((windowMs - (now - entry.windowStart)) / 1000);
    return { allowed: false, retryAfter };
  }

  return { allowed: true, retryAfter: 0 };
}

/**
 * Reset rate limit for a specific function
 */
export function resetRateLimit(fn) {
  delete rateLimits[fn];
}

/**
 * Reset all rate limits
 */
export function resetAllRateLimits() {
  Object.keys(rateLimits).forEach(k => delete rateLimits[k]);
}
