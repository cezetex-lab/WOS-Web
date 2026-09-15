import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('Rate Limiter - Full Coverage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('allows calls within default limit', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    const r = checkRateLimit('test_fn');
    expect(r.allowed).toBe(true);
  });

  it('tracks call count correctly', async () => {
    const { checkRateLimit, getRateLimitStatus } = await import('../../src/lib/rate-limiter.js');
    checkRateLimit('count_test');
    checkRateLimit('count_test');
    checkRateLimit('count_test');
    const status = getRateLimitStatus('count_test');
    expect(status.used).toBe(3);
  });

  it('blocks when limit exceeded', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    for (let i = 0; i < 30; i++) checkRateLimit('block_test');
    const r = checkRateLimit('block_test');
    expect(r.allowed).toBe(false);
    expect(r.retryAfter).toBeGreaterThan(0);
  });

  it('returns correct status for unknown function', async () => {
    const { getRateLimitStatus } = await import('../../src/lib/rate-limiter.js');
    const status = getRateLimitStatus('unknown_fn');
    expect(status.used).toBe(0);
    expect(status.limit).toBe(30);
  });

  it('login functions have stricter limits', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    // login_worker has 5 per 5 min limit
    for (let i = 0; i < 5; i++) checkRateLimit('login_worker');
    const r = checkRateLimit('login_worker');
    expect(r.allowed).toBe(false);
  });

  it('owner_toggle_lock has 5 per min limit', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    for (let i = 0; i < 5; i++) checkRateLimit('owner_toggle_lock');
    const r = checkRateLimit('owner_toggle_lock');
    expect(r.allowed).toBe(false);
  });
});
