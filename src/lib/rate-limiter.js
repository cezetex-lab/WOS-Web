// ============================================================
// rate-limiter.js — Client-side rate limiting for RPC calls
// ============================================================
// CATATAN: ini hanya friksi sisi klien (UX guard). Penegakan
// rate limit yang sesungguhnya tetap di server (DB/edge).

const rateLimits = {};
const DEFAULT_WINDOW_MS = 60000; // 1 menit
const DEFAULT_MAX_REQUESTS = 30;

// Batas per fungsi — fungsi sensitif (login, toggle owner) dapat
// window lebih ketat dari default.
// Format: fnName -> { maxRequests, windowMs }
const FUNCTION_LIMITS = {
  login_worker: { maxRequests: 5, windowMs: 5 * DEFAULT_WINDOW_MS },  // 5 per 5 menit
  owner_toggle_lock: { maxRequests: 5, windowMs: DEFAULT_WINDOW_MS }, // 5 per menit
};

// Resolusi limit efektif: argumen eksplisit > override per-fungsi > default.
function limitsFor(fn, maxRequests, windowMs) {
  const override = FUNCTION_LIMITS[fn];
  return {
    maxRequests: maxRequests ?? (override ? override.maxRequests : DEFAULT_MAX_REQUESTS),
    windowMs: windowMs ?? (override ? override.windowMs : DEFAULT_WINDOW_MS),
  };
}

/**
 * Check if a function call is rate-limited
 * @param {string} fn - RPC function name
 * @param {number} [maxRequests] - max calls per window (default: per-function override atau 30)
 * @param {number} [windowMs] - time window in ms (default: per-function override atau 60000)
 * @returns {{ allowed: boolean, retryAfter: number }}
 */
export function checkRateLimit(fn, maxRequests, windowMs) {
  const limits = limitsFor(fn, maxRequests, windowMs);
  const now = Date.now();

  if (!rateLimits[fn]) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  const entry = rateLimits[fn];

  // Reset window if expired
  if (now - entry.windowStart > limits.windowMs) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  // Increment count
  entry.count++;

  // Check limit
  if (entry.count > limits.maxRequests) {
    const retryAfter = Math.ceil((limits.windowMs - (now - entry.windowStart)) / 1000);
    return { allowed: false, retryAfter };
  }

  return { allowed: true, retryAfter: 0 };
}

/**
 * Get current usage status for a function
 * @param {string} fn - RPC function name
 * @returns {{ used: number, limit: number, remaining: number }}
 */
export function getRateLimitStatus(fn) {
  const { maxRequests } = limitsFor(fn);
  const entry = rateLimits[fn];
  const used = entry ? entry.count : 0;
  return {
    used,
    limit: maxRequests,
    remaining: Math.max(0, maxRequests - used),
  };
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
