import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock sessionStorage
const mockStorage = {};
const sessionStorageMock = {
  getItem: vi.fn((key) => mockStorage[key] || null),
  setItem: vi.fn((key, value) => { mockStorage[key] = value; }),
  removeItem: vi.fn((key) => { delete mockStorage[key]; }),
  clear: vi.fn(() => { Object.keys(mockStorage).forEach(k => delete mockStorage[k]); }),
};
Object.defineProperty(globalThis, 'sessionStorage', { value: sessionStorageMock });
Object.defineProperty(globalThis, 'window', { value: { sessionStorage: sessionStorageMock } });

describe('Supabase Browser - Session Management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStorage).forEach(k => delete mockStorage[k]);
  });

  it('setSession stores JSON correctly', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test', role: 'worker', role_level: 3 };
    setSession(user);
    expect(sessionStorageMock.setItem).toHaveBeenCalledWith('wos_user', JSON.stringify(user));
  });

  it('getSession retrieves parsed data', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test' };
    mockStorage['wos_user'] = JSON.stringify(user);
    expect(getSession()).toEqual(user);
  });

  it('getSession returns null when empty', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    expect(getSession()).toBeNull();
  });

  it('getSession handles corrupted JSON safely', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage['wos_user'] = 'CORRUPTED{{}}';
    expect(getSession()).toBeNull();
    // Should also clean up corrupted data
    expect(mockStorage['wos_user']).toBeUndefined();
  });

  it('clearSession removes data', async () => {
    const { clearSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage['wos_user'] = JSON.stringify({ nrp: 'NRP001' });
    clearSession();
    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith('wos_user');
  });

  it('setSession handles null/undefined gracefully', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');
    expect(() => setSession(null)).not.toThrow();
    expect(() => setSession(undefined)).not.toThrow();
  });
});

describe('Supabase Browser - RPC Helper', () => {
  it('rpc function exists and is callable', async () => {
    const { rpc } = await import('../../src/lib/supabase-browser.js');
    expect(typeof rpc).toBe('function');
  });
});
