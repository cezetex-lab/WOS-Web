/**
 * Client-side Rate Limiter
 * Prevents excessive RPC calls per user session.
 * Configurable per-function limits.
 */

const callLog = new Map(); // key -> { count, windowStart }

const DEFAULT_LIMITS = {
  _default: { maxCalls: 30, windowMs: 60000 }, // 30 calls per minute
  owner_toggle_lock: { maxCalls: 5, windowMs: 60000 }, // 5 toggles per minute
  owner_set_tier: { maxCalls: 5, windowMs: 60000 },
  check_module_access: { maxCalls: 20, windowMs: 60000 },
  login_worker: { maxCalls: 5, windowMs: 300000 }, // 5 per 5 minutes
  login_admin: { maxCalls: 5, windowMs: 300000 },
  verify_worker_otp: { maxCalls: 5, windowMs: 300000 },
};

/**
 * Check if a call is allowed under rate limit
 * @param {string} fn - Function name
 * @returns {{ allowed: boolean, retryAfter?: number }}
 */
export function checkRateLimit(fn) {
  const limits = DEFAULT_LIMITS[fn] || DEFAULT_LIMITS._default;
  const now = Date.now();
  const entry = callLog.get(fn);

  if (!entry || now - entry.windowStart > limits.windowMs) {
    // New window
    callLog.set(fn, { count: 1, windowStart: now });
    return { allowed: true };
  }

  if (entry.count >= limits.maxCalls) {
    const retryAfter = Math.ceil((entry.windowStart + limits.windowMs - now) / 1000);
    return { allowed: false, retryAfter };
  }

  entry.count++;
  return { allowed: true };
}

/**
 * Get rate limit status for display
 */
export function getRateLimitStatus(fn) {
  const limits = DEFAULT_LIMITS[fn] || DEFAULT_LIMITS._default;
  const entry = callLog.get(fn);
  if (!entry) return { used: 0, limit: limits.maxCalls, windowMs: limits.windowMs };
  return {
    used: entry.count,
    limit: limits.maxCalls,
    windowMs: limits.windowMs,
    remaining: Math.max(0, limits.maxCalls - entry.count),
  };
}
