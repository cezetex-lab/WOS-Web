import { describe, it, expect, beforeEach, vi } from 'vitest';

const mockStore = {};
const localStorageMock = {
  getItem: vi.fn((key) => mockStore[key] || null),
  setItem: vi.fn((key, value) => { mockStore[key] = value; }),
  removeItem: vi.fn((key) => { delete mockStore[key]; }),
  key: vi.fn((i) => Object.keys(mockStore)[i] || null),
  get length() { return Object.keys(mockStore).length; },
  clear: vi.fn(() => { Object.keys(mockStore).forEach(k => delete mockStore[k]); }),
};

Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock });

describe('Client Cache', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStore).forEach(k => delete mockStore[k]);
  });

  it('cacheSet stores data with expiry', async () => {
    const { cacheSet } = await import('../../src/lib/cache.js');
    cacheSet('test_key', { data: 'hello' }, 300);
    expect(localStorageMock.setItem).toHaveBeenCalled();
    const stored = JSON.parse(Object.values(mockStore)[0]);
    expect(stored.data).toEqual({ data: 'hello' });
    expect(stored.expires).toBeGreaterThan(Date.now());
  });

  it('cacheGet returns data within TTL', async () => {
    const { cacheSet, cacheGet } = await import('../../src/lib/cache.js');
    cacheSet('ttl_key', 'test_value', 300);
    const result = cacheGet('ttl_key');
    expect(result).toBe('test_value');
  });

  it('cacheGet returns null for expired data', async () => {
    const { cacheGet } = await import('../../src/lib/cache.js');
    // Insert already-expired data directly
    mockStore['wos_cache:expired_key'] = JSON.stringify({ data: 'value', expires: Date.now() - 1000 });
    const result = cacheGet('expired_key');
    expect(result).toBeNull();
  });

  it('cacheRemove deletes specific key', async () => {
    const { cacheSet, cacheRemove } = await import('../../src/lib/cache.js');
    cacheSet('remove_key', 'data', 300);
    cacheRemove('remove_key');
    expect(localStorageMock.removeItem).toHaveBeenCalled();
  });
});
