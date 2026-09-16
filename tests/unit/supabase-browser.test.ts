import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock sessionStorage
const mockStorage: Record<string, string> = {};
const sessionStorageMock = {
  getItem: vi.fn((key: string) => mockStorage[key] || null),
  setItem: vi.fn((key: string, value: string) => { mockStorage[key] = value; }),
  removeItem: vi.fn((key: string) => { delete mockStorage[key]; }),
  clear: vi.fn(() => { Object.keys(mockStorage).forEach(k => delete mockStorage[k]); }),
};
Object.defineProperty(globalThis, 'sessionStorage', { value: sessionStorageMock });
Object.defineProperty(globalThis, 'window', { value: { sessionStorage: sessionStorageMock } });

const KEY = 'wos_user_v2';
const FUTURE = new Date(Date.now() + 3_600_000).toISOString();

describe('Supabase Browser - Session Management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStorage).forEach(k => delete mockStorage[k]);
  });

  it('setSession stores JSON correctly (key v2 + stempel entry/expires_at)', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');
    setSession({ nrp: 'NRP001', nama: 'Test', role: 'worker', role_level: 3, business_unit_id: 'BU-HQ' });
    const stored = JSON.parse(mockStorage[KEY]);
    expect(stored).toMatchObject({ nrp: 'NRP001', nama: 'Test', role: 'worker', role_level: 3 });
    expect(stored.entry).toBe('worker');
    expect(new Date(stored.expires_at).getTime()).toBeGreaterThan(Date.now());
  });

  it('getSession retrieves parsed data', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test', role: 'worker', entry: 'worker', expires_at: FUTURE };
    mockStorage[KEY] = JSON.stringify(user);
    expect(getSession()).toEqual(user);
  });

  it('getSession returns null when empty', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    expect(getSession()).toBeNull();
  });

  it('getSession menolak sesi tanpa expires_at (fail-closed)', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', nama: 'Test' });
    expect(getSession()).toBeNull();
  });

  it('getSession handles corrupted JSON safely', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = 'CORRUPTED{{}}';
    expect(getSession()).toBeNull();
    // Should also clean up corrupted data
    expect(mockStorage[KEY]).toBeUndefined();
  });

  it('clearSession removes data', async () => {
    const { clearSession } = await import('../../src/lib/supabase-browser.js');
    mockStorage[KEY] = JSON.stringify({ nrp: 'NRP001', entry: 'worker', expires_at: FUTURE });
    clearSession();
    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith(KEY);
    expect(mockStorage[KEY]).toBeUndefined();
  });

  it('setSession handles null/undefined gracefully', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');
    expect(() => setSession(null)).not.toThrow();
    // @ts-expect-error — runtime guard: plain-JS callers may pass undefined.
    expect(() => setSession(undefined)).not.toThrow();
  });
});

describe('Supabase Browser - RPC Helper', () => {
  it('rpc function exists and is callable', async () => {
    const { rpc } = await import('../../src/lib/supabase-browser.js');
    expect(typeof rpc).toBe('function');
  });
});
