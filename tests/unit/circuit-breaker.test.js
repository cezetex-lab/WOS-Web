import { describe, it, expect } from 'vitest';
import { CircuitBreaker } from '../../src/lib/circuit-breaker';

describe('CircuitBreaker', () => {
  it('starts in CLOSED state', () => {
    const cb = new CircuitBreaker();
    expect(cb.getState().state).toBe('CLOSED');
  });

  it('opens after failure threshold', async () => {
    const cb = new CircuitBreaker({ failureThreshold: 3 });
    for (let i = 0; i < 3; i++) {
      try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    }
    expect(cb.getState().state).toBe('OPEN');
  });

  it('rejects calls when OPEN', async () => {
    const cb = new CircuitBreaker({ failureThreshold: 1 });
    try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    await expect(cb.execute(() => Promise.resolve('ok'))).rejects.toThrow('Circuit breaker is OPEN');
  });

  it('resets failure count on success', async () => {
    const cb = new CircuitBreaker({ failureThreshold: 3 });
    try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    try { await cb.execute(() => Promise.reject(new Error('fail'))); } catch {}
    await cb.execute(() => Promise.resolve('ok'));
    expect(cb.getState().failureCount).toBe(0);
  });
});
