/**
 * rate-limiter.ts — Client-side rate limiting for RPC calls (TypeScript)
 *
 * CATATAN: ini hanya friksi sisi klien (UX guard). Penegakan
 * rate limit yang sesungguhnya tetap di server (DB/edge).
 */

interface RateLimitEntry {
  count: number;
  windowStart: number;
}

interface FunctionLimit {
  maxRequests: number;
  windowMs: number;
}

export interface RateLimitResult {
  allowed: boolean;
  retryAfter: number;
}

export interface RateLimitStatus {
  used: number;
  limit: number;
  remaining: number;
}

const rateLimits: Record<string, RateLimitEntry> = {};
const DEFAULT_WINDOW_MS = 60_000; // 1 minute
const DEFAULT_MAX_REQUESTS = 30;

const FUNCTION_LIMITS: Record<string, FunctionLimit> = {
  login_worker: { maxRequests: 5, windowMs: 5 * DEFAULT_WINDOW_MS },
  login_worker_by_email: { maxRequests: 5, windowMs: 5 * DEFAULT_WINDOW_MS },
  owner_toggle_lock: { maxRequests: 5, windowMs: DEFAULT_WINDOW_MS },
};

function limitsFor(
  fn: string,
  maxRequests?: number,
  windowMs?: number,
): FunctionLimit {
  const override = FUNCTION_LIMITS[fn];
  return {
    maxRequests: maxRequests ?? (override ? override.maxRequests : DEFAULT_MAX_REQUESTS),
    windowMs: windowMs ?? (override ? override.windowMs : DEFAULT_WINDOW_MS),
  };
}

/**
 * Check if a function call is rate-limited
 */
export function checkRateLimit(
  fn: string,
  maxRequests?: number,
  windowMs?: number,
): RateLimitResult {
  const limits = limitsFor(fn, maxRequests, windowMs);
  const now = Date.now();

  if (!rateLimits[fn]) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  const entry = rateLimits[fn];

  if (now - entry.windowStart > limits.windowMs) {
    rateLimits[fn] = { count: 1, windowStart: now };
    return { allowed: true, retryAfter: 0 };
  }

  entry.count++;

  if (entry.count > limits.maxRequests) {
    const retryAfter = Math.ceil((limits.windowMs - (now - entry.windowStart)) / 1000);
    return { allowed: false, retryAfter };
  }

  return { allowed: true, retryAfter: 0 };
}

/**
 * Get current usage status for a function
 */
export function getRateLimitStatus(fn: string): RateLimitStatus {
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
export function resetRateLimit(fn: string): void {
  delete rateLimits[fn];
}

/**
 * Reset all rate limits
 */
export function resetAllRateLimits(): void {
  Object.keys(rateLimits).forEach((k) => delete rateLimits[k]);
}
