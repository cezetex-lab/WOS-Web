import { describe, it, expect, beforeEach, vi } from 'vitest';

describe('RPC Rate Limiter', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('allows calls within default limit', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    
    const r1 = checkRateLimit('owner_toggle_lock');
    expect(r1.allowed).toBe(true);
    
    const r2 = checkRateLimit('owner_toggle_lock');
    expect(r2.allowed).toBe(true);
  });

  it('blocks calls over limit', async () => {
    const { checkRateLimit } = await import('../../src/lib/rate-limiter.js');
    
    // owner_toggle_lock has limit of 5
    for (let i = 0; i < 5; i++) {
      checkRateLimit('rate_test_block');
    }
    
    // Exhaust limit for a custom function
    for (let i = 0; i < 30; i++) {
      checkRateLimit('rate_test_custom');
    }
    
    const result = checkRateLimit('rate_test_custom');
    expect(result.allowed).toBe(false);
    expect(result.retryAfter).toBeGreaterThan(0);
  });

  it('status shows correct counts', async () => {
    const { checkRateLimit, getRateLimitStatus } = await import('../../src/lib/rate-limiter.js');
    
    checkRateLimit('rate_test_status');
    checkRateLimit('rate_test_status');
    
    const status = getRateLimitStatus('rate_test_status');
    expect(status.used).toBe(2);
    expect(status.limit).toBe(30); // default limit
    expect(status.remaining).toBe(28);
  });
});

describe('Circuit Breaker', () => {
  it('starts in CLOSED state', async () => {
    const { CircuitBreaker } = await import('../../src/lib/circuit-breaker.js');
    
    const cb = new CircuitBreaker({ failureThreshold: 3, resetTimeout: 1000 });
    expect(cb.state).toBe('CLOSED');
  });

  it('opens after threshold failures', async () => {
    const { CircuitBreaker } = await import('../../src/lib/circuit-breaker.js');
    
    const cb = new CircuitBreaker({ failureThreshold: 3, resetTimeout: 1000 });
    
    for (let i = 0; i < 3; i++) {
      try {
        await cb.execute(() => Promise.reject(new Error('fail')));
      } catch {}
    }
    
    expect(cb.state).toBe('OPEN');
  });

  it('rejects when OPEN', async () => {
    const { CircuitBreaker } = await import('../../src/lib/circuit-breaker.js');
    
    const cb = new CircuitBreaker({ failureThreshold: 2, resetTimeout: 60000 });
    
    try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    
    await expect(cb.execute(() => Promise.resolve('ok'))).rejects.toThrow();
  });
});
