import { describe, it, expect } from 'vitest';
import { checkRateLimit, getRateLimitStatus } from '../../src/lib/rate-limiter';

describe('RateLimiter', () => {
  it('allows calls under limit', () => {
    const result = checkRateLimit('test_fn');
    expect(result.allowed).toBe(true);
  });

  it('blocks calls over limit', () => {
    // owner_toggle_lock: max 5 per minute
    for (let i = 0; i < 5; i++) checkRateLimit('owner_toggle_lock');
    const result = checkRateLimit('owner_toggle_lock');
    expect(result.allowed).toBe(false);
    expect(result.retryAfter).toBeGreaterThan(0);
  });

  it('reports status correctly', () => {
    checkRateLimit('status_test');
    const status = getRateLimitStatus('status_test');
    expect(status.used).toBe(1);
    expect(status.remaining).toBeGreaterThan(0);
  });
});
