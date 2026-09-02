import { describe, it, expect, beforeEach, vi } from 'vitest';

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

describe('Session Management', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.keys(mockStorage).forEach(k => delete mockStorage[k]);
  });

  it('setSession stores user data as JSON', async () => {
    const { setSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test User', role: 'worker' };
    
    setSession(user);
    
    expect(sessionStorageMock.setItem).toHaveBeenCalledWith(
      'wos_user',
      JSON.stringify(user)
    );
  });

  it('getSession returns parsed user data', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    const user = { nrp: 'NRP001', nama: 'Test User' };
    
    mockStorage['wos_user'] = JSON.stringify(user);
    
    const result = getSession();
    expect(result).toEqual(user);
  });

  it('getSession returns null when no session', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    
    const result = getSession();
    expect(result).toBeNull();
  });

  it('clearSession removes session data', async () => {
    const { clearSession } = await import('../../src/lib/supabase-browser.js');
    
    mockStorage['wos_user'] = JSON.stringify({ nrp: 'NRP001' });
    
    clearSession();
    
    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith('wos_user');
  });

  it('getSession handles corrupted JSON gracefully', async () => {
    const { getSession } = await import('../../src/lib/supabase-browser.js');
    
    mockStorage['wos_user'] = 'NOT VALID JSON';
    
    // Should not throw, should return null or handle gracefully
    expect(() => getSession()).not.toThrow();
  });
});
