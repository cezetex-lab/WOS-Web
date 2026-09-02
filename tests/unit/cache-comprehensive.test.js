import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockStore = {};
const localStorageMock = {
  getItem: vi.fn((key) => mockStore[key] || null),
  setItem: vi.fn((key, value) => { mockStore[key] = value; }),
  removeItem: vi.fn((key) => { delete mockStore[key]; }),
  get length() { return Object.keys(mockStore).length; },
};
Object.defineProperty(localStorageMock, 'key', {
  value: (i) => Object.keys(mockStore)[i] || null,
});
Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock });

describe('Cache - Full Coverage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStore).forEach(k => delete mockStore[k]);
  });

  it('cacheSet stores data', async () => {
    const { cacheSet } = await import('../../src/lib/cache.js');
    cacheSet('k1', { v: 1 }, 60);
    expect(localStorageMock.setItem).toHaveBeenCalled();
  });

  it('cacheGet retrieves data', async () => {
    const { cacheSet, cacheGet } = await import('../../src/lib/cache.js');
    cacheSet('k2', 'val', 60);
    expect(cacheGet('k2')).toBe('val');
  });

  it('cacheGet returns null for expired', async () => {
    const { cacheGet } = await import('../../src/lib/cache.js');
    mockStore['wos_cache:exp'] = JSON.stringify({ data: 'x', expires: Date.now() - 1000 });
    expect(cacheGet('exp')).toBeNull();
  });

  it('cacheGet returns null for missing', async () => {
    const { cacheGet } = await import('../../src/lib/cache.js');
    expect(cacheGet('missing')).toBeNull();
  });

  it('cacheRemove works', async () => {
    const { cacheSet, cacheRemove } = await import('../../src/lib/cache.js');
    cacheSet('rm', 'd', 60);
    cacheRemove('rm');
    expect(localStorageMock.removeItem).toHaveBeenCalled();
  });

  it('getCacheStats returns stats', async () => {
    const { getCacheStats } = await import('../../src/lib/cache.js');
    const s = getCacheStats();
    expect(s).toHaveProperty('totalEntries');
  });
});
